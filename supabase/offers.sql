-- Tilbud fra bookingansvarlig til artistportalen.
-- Kjør filen hvis databasen allerede finnes. Nye installasjoner har det i schema.sql.
--
-- Pris vises ikke på den offentlige artistsiden. Honorar ligger bare i tilbudet.

create table if not exists public.artist_offers (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.artists (id) on delete cascade,
  dato date not null,
  honorar integer not null check (honorar >= 0),
  spillested text not null,
  arrangor_navn text not null,
  melding text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined', 'archived')),
  created_at timestamptz not null default now()
);

create index if not exists artist_offers_artist_status_idx
  on public.artist_offers (artist_id, status, dato);

create unique index if not exists artist_offers_pending_dato_idx
  on public.artist_offers (artist_id, dato)
  where status = 'pending';

alter table public.artist_offers
  add column if not exists avslag_kommentar text not null default '';

comment on table public.artist_offers is 'Tilbud som bookingansvarlig sender, og som artisten må godkjenne.';

alter table public.artist_offers enable row level security;

drop policy if exists artist_offers_own_read on public.artist_offers;
create policy artist_offers_own_read on public.artist_offers
for select to authenticated
using (artist_id = public.current_artist_id());

revoke all on table public.artist_offers from anon, authenticated;
grant select on table public.artist_offers to authenticated;

create or replace function public.admin_send_offer(
  p_pin text,
  p_artist_id uuid,
  p_dato date,
  p_honorar integer,
  p_spillested text,
  p_arrangor text,
  p_melding text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  if p_dato is null or p_dato < current_date then
    raise exception 'Velg en dato som ikke har passert';
  end if;

  if p_honorar is null or p_honorar < 0 then
    raise exception 'Honorar må være 0 eller høyere';
  end if;

  if length(trim(coalesce(p_spillested, ''))) = 0
     or length(trim(coalesce(p_arrangor, ''))) = 0 then
    raise exception 'Spillested og arrangør må fylles ut';
  end if;

  if not exists (select 1 from public.artists where id = p_artist_id) then
    raise exception 'Fant ikke artisten';
  end if;

  if exists (
    select 1 from public.gigs
    where artist_id = p_artist_id and dato = p_dato
  ) then
    raise exception 'Artisten er allerede booket denne datoen';
  end if;

  if exists (
    select 1 from public.artist_offers
    where artist_id = p_artist_id
      and dato = p_dato
      and status = 'pending'
  ) then
    raise exception 'Det ligger allerede et tilbud på denne datoen';
  end if;

  insert into public.artist_offers (
    artist_id, dato, honorar, spillested, arrangor_navn, melding, status
  )
  values (
    p_artist_id,
    p_dato,
    p_honorar,
    trim(p_spillested),
    trim(p_arrangor),
    trim(coalesce(p_melding, '')),
    'pending'
  );
end;
$$;

create or replace function public.my_offers()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.current_artist_id() is null then
    raise exception 'Logg inn på nytt';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'artist_id', o.artist_id,
        'dato', o.dato,
        'honorar', o.honorar,
        'spillested', o.spillested,
        'arrangor_navn', o.arrangor_navn,
        'melding', o.melding,
        'status', o.status,
        'avslag_kommentar', o.avslag_kommentar,
        'svarfrist', o.svarfrist,
        'booking_id', o.booking_id
      )
      order by case when o.status = 'pending' then 0 else 1 end, o.dato
    )
    from public.artist_offers o
    left join public.bookings b on b.id = o.booking_id
    where o.artist_id = public.current_artist_id()
      and o.status in ('pending', 'declined')
      and (o.booking_id is null or b.arkivert_at is null)
  ), '[]'::jsonb);
end;
$$;

drop function if exists public.respond_to_offer(uuid, boolean);

create or replace function public.respond_to_offer(
  p_offer_id uuid,
  p_approve boolean,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  offer public.artist_offers%rowtype;
  note text;
begin
  if auth.uid() is null or public.current_artist_id() is null then
    raise exception 'Logg inn på nytt';
  end if;

  select * into offer
  from public.artist_offers
  where id = p_offer_id
    and artist_id = public.current_artist_id()
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Forespørselen finnes ikke';
  end if;

  if not coalesce(p_approve, false) then
    if length(trim(coalesce(p_comment, ''))) = 0 then
      raise exception 'Skriv hvorfor forespørselen avslås';
    end if;
    update public.artist_offers
    set status = 'declined',
        avslag_kommentar = trim(p_comment)
    where id = offer.id;
    return;
  end if;

  if exists (
    select 1 from public.gigs
    where artist_id = offer.artist_id and dato = offer.dato
  ) then
    raise exception 'Datoen er allerede booket';
  end if;

  note := 'Honorar: ' || offer.honorar::text || ' kr';
  if length(trim(offer.melding)) > 0 then
    note := note || E'\n' || trim(offer.melding);
  end if;

  insert into public.bookings (
    artist_id,
    dato,
    status,
    arrangor_navn,
    organisasjon,
    kontaktperson,
    epost,
    telefon,
    spillested,
    notater
  )
  values (
    offer.artist_id,
    offer.dato,
    'confirmed',
    offer.arrangor_navn,
    offer.arrangor_navn,
    '',
    '',
    '',
    offer.spillested,
    note
  );

  update public.artist_offers
  set status = 'approved'
  where id = offer.id;
end;
$$;

create or replace function public.undo_offer_decline(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  offer public.artist_offers%rowtype;
  deadline timestamptz;
begin
  if auth.uid() is null or public.current_artist_id() is null then
    raise exception 'Logg inn på nytt';
  end if;

  select * into offer
  from public.artist_offers
  where id = p_offer_id
    and artist_id = public.current_artist_id()
    and status = 'declined'
  for update;

  if not found then
    raise exception 'Forespørselen finnes ikke';
  end if;

  if offer.booking_id is not null
     and exists (
       select 1 from public.bookings
       where id = offer.booking_id and arkivert_at is not null
     ) then
    raise exception 'Forespørselen er arkivert og kan ikke angres';
  end if;

  if exists (
    select 1 from public.artist_offers
    where artist_id = offer.artist_id
      and dato = offer.dato
      and status = 'pending'
      and id <> offer.id
  ) then
    raise exception 'Det ligger allerede et tilbud på denne datoen';
  end if;

  deadline := now() + interval '48 hours';

  update public.artist_offers
  set status = 'pending',
      avslag_kommentar = '',
      svarfrist = deadline
  where id = offer.id;

  if offer.booking_id is not null then
    update public.bookings
    set status = 'with_artist',
        avslag_kommentar = '',
        sendt_artist_at = coalesce(sendt_artist_at, now()),
        svarfrist = deadline
    where id = offer.booking_id
      and status = 'declined'
      and arkivert_at is null;
  end if;
end;
$$;

create or replace function public.admin_declined_offers(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'artist_id', o.artist_id,
        'artist_navn', a.navn,
        'dato', o.dato,
        'honorar', o.honorar,
        'spillested', o.spillested,
        'arrangor_navn', o.arrangor_navn,
        'melding', o.melding,
        'status', o.status,
        'avslag_kommentar', o.avslag_kommentar
      )
      order by o.dato desc
    )
    from public.artist_offers o
    join public.artists a on a.id = o.artist_id
    left join public.bookings b on b.id = o.booking_id
    where o.status = 'declined'
      and (o.booking_id is null or b.arkivert_at is null)
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_send_offer(text, uuid, date, integer, text, text, text) from public;
grant execute on function public.admin_send_offer(text, uuid, date, integer, text, text, text) to anon, authenticated;

revoke all on function public.my_offers() from public;
grant execute on function public.my_offers() to authenticated;

revoke all on function public.respond_to_offer(uuid, boolean, text) from public;
grant execute on function public.respond_to_offer(uuid, boolean, text) to authenticated;

revoke all on function public.undo_offer_decline(uuid) from public;
grant execute on function public.undo_offer_decline(uuid) to authenticated;

revoke all on function public.admin_declined_offers(text) from public;
grant execute on function public.admin_declined_offers(text) to anon, authenticated;
