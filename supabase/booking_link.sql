-- Kobler en allerede opprettet database til felles booking-ID.
-- Trygt å kjøre på nytt etter en eldre schema.sql.
-- Nye databaser trenger bare schema.sql.
--
-- Hver gig må ha booking_id. Slett eller knytt rader uten booking før du kjører.

do $$
begin
  if exists (select 1 from public.gigs where booking_id is null) then
    raise exception 'Det finnes gigs uten booking_id. Knytt eller slett dem før denne migreringen.';
  end if;
end $$;

alter table public.gigs drop constraint if exists gigs_booking_id_fkey;
alter table public.gigs alter column booking_id set not null;
alter table public.gigs
  add constraint gigs_booking_id_fkey
  foreign key (booking_id) references public.bookings (id) on delete restrict;

drop index if exists public.gigs_artist_dato_idx;
create unique index gigs_artist_dato_idx on public.gigs (artist_id, dato);

create unique index if not exists bookings_confirmed_artist_dato_idx
  on public.bookings (artist_id, dato)
  where status = 'confirmed';

comment on column public.bookings.id is 'Felles hendelses-ID. Gjenbrukes som gigs.booking_id fra forespørsel til kjøreplan.';
comment on column public.gigs.booking_id is 'Samme ID som bookingen. Artist, dato og arrangør hentes fra den raden.';
comment on column public.gigs.arrangor is 'Speil av arrangørfeltene på bookingen, til artist-appen. Produksjonssiden leser feltene fra bookingen via booking_id.';

drop function if exists public.gig_json(public.gigs, text);

create or replace function public.booking_arrangor(p_booking public.bookings)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'arrangor_navn', p_booking.arrangor_navn,
    'organisasjon', p_booking.organisasjon,
    'kontaktperson', p_booking.kontaktperson,
    'epost', p_booking.epost,
    'telefon', p_booking.telefon,
    'spillested', p_booking.spillested,
    'notater', p_booking.notater
  );
$$;

create or replace function public.gigs_match_booking()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
begin
  select * into booking from public.bookings where id = new.booking_id;
  if not found then
    raise exception 'Gigen må peke på en booking';
  end if;
  if new.artist_id is distinct from booking.artist_id
     or new.dato is distinct from booking.dato then
    raise exception 'Gigen må ha samme artist og dato som bookingen';
  end if;
  return new;
end;
$$;

drop trigger if exists gigs_match_booking on public.gigs;
create trigger gigs_match_booking
before insert or update of booking_id, artist_id, dato on public.gigs
for each row
execute function public.gigs_match_booking();

create or replace function public.bookings_guard_confirmed()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status = 'confirmed'
     and (
       new.artist_id is distinct from old.artist_id
       or new.dato is distinct from old.dato
     ) then
    raise exception 'Artist og dato kan ikke endres etter at bookingen er bekreftet';
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_guard_confirmed on public.bookings;
create trigger bookings_guard_confirmed
before update on public.bookings
for each row
execute function public.bookings_guard_confirmed();

create or replace function public.bookings_sync_confirmed_gig()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  token text;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'confirmed' then
    update public.gigs
    set arrangor = public.booking_arrangor(new),
        updated_at = now()
    where booking_id = new.id;
    return new;
  end if;

  if exists (
    select 1
    from public.gigs
    where artist_id = new.artist_id
      and dato = new.dato
      and booking_id <> new.id
  ) then
    raise exception 'Artisten er allerede booket denne datoen';
  end if;

  if not exists (select 1 from public.gigs where booking_id = new.id) then
    token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
    insert into public.gigs (
      booking_token,
      artist_id,
      booking_id,
      dato,
      status,
      arrangor,
      produksjon
    )
    values (
      token,
      new.artist_id,
      new.id,
      new.dato,
      'confirmed',
      public.booking_arrangor(new),
      '{}'::jsonb
    );
  end if;

  insert into public.availability (artist_id, dato, er_tilgjengelig)
  values (new.artist_id, new.dato, false)
  on conflict (artist_id, dato) do update
  set er_tilgjengelig = false;

  return new;
end;
$$;

drop trigger if exists bookings_sync_confirmed_gig on public.bookings;
create trigger bookings_sync_confirmed_gig
after insert or update on public.bookings
for each row
execute function public.bookings_sync_confirmed_gig();

alter table public.gigs
  add column if not exists travel_status text not null default 'not_booked',
  add column if not exists arrival_time timestamptz,
  add column if not exists pickup_location text not null default '',
  add column if not exists departure_time timestamptz,
  add column if not exists dropoff_location text not null default '';

create or replace function public.gig_json(p_gig public.gigs)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
  artist_navn text;
begin
  select * into booking from public.bookings where id = p_gig.booking_id;
  if not found then
    raise exception 'Bookingen mangler for denne jobben';
  end if;

  select navn into artist_navn from public.artists where id = booking.artist_id;

  return jsonb_build_object(
    'id', p_gig.id,
    'booking_id', booking.id,
    'booking_token', p_gig.booking_token,
    'artist_id', booking.artist_id,
    'artist_navn', artist_navn,
    'dato', booking.dato,
    'status', p_gig.status,
    'arrangor', public.booking_arrangor(booking),
    'produksjon', p_gig.produksjon,
    'travel_status', p_gig.travel_status,
    'arrival_time', p_gig.arrival_time,
    'pickup_location', p_gig.pickup_location,
    'departure_time', p_gig.departure_time,
    'dropoff_location', p_gig.dropoff_location
  );
end;
$$;

create or replace function public.get_gig_by_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  payload jsonb;
begin
  select public.gig_json(g)
    into payload
  from public.gigs g
  where g.booking_token = p_token;

  return payload;
end;
$$;

create or replace function public.save_production_plan(p_token text, p_produksjon jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  required_key text;
  clock_value text;
  payload jsonb;
  required_keys text[] := array['get_in', 'lydprove', 'get_in_show', 'showstart', 'curfew'];
begin
  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Fant ingen jobb for denne lenken';
  end if;

  if coalesce(trim(p_produksjon->>'arrangementsnavn'), '') = '' then
    raise exception 'Arrangementsnavn mangler';
  end if;

  if coalesce(trim(p_produksjon->>'overnatting_navn'), '') = '' then
    raise exception 'Overnattingssted mangler';
  end if;

  foreach required_key in array required_keys
  loop
    clock_value := p_produksjon->>required_key;
    if clock_value is null or clock_value !~ '^\d{2}:\d{2}$' then
      raise exception 'Alle tider må fylles ut som HH:MM';
    end if;
  end loop;

  update public.gigs
  set produksjon = p_produksjon,
      status = 'ready',
      updated_at = now()
  where booking_token = p_token;

  if not found then
    raise exception 'Fant ingen jobb for denne lenken';
  end if;

  select public.gig_json(g)
    into payload
  from public.gigs g
  where g.booking_token = p_token;

  return payload;
end;
$$;

create or replace function public.confirm_booking(p_booking_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
  token text;
begin
  select * into booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Fant ikke booking';
  end if;

  if booking.status = 'declined' then
    raise exception 'Avslått forespørsel kan ikke bekreftes';
  end if;

  if booking.status = 'inquiry' then
    update public.bookings
    set status = 'confirmed'
    where id = booking.id;
  end if;

  select g.booking_token into token
  from public.gigs g
  where g.booking_id = p_booking_id;

  if token is null then
    raise exception 'Bekreftelsen opprettet ingen jobb';
  end if;

  return token;
end;
$$;

revoke all on function public.confirm_booking(uuid) from public, anon, authenticated;
grant execute on function public.confirm_booking(uuid) to service_role;
grant execute on function public.get_gig_by_token(text) to anon, authenticated;
grant execute on function public.save_production_plan(text, jsonb) to anon, authenticated;
revoke all on function public.booking_arrangor(public.bookings) from public, anon, authenticated;
revoke all on function public.gig_json(public.gigs) from public, anon, authenticated;
revoke all on function public.gigs_match_booking() from public, anon, authenticated;
revoke all on function public.bookings_guard_confirmed() from public, anon, authenticated;
grant execute on function public.bookings_sync_confirmed_gig() to anon, authenticated;

create or replace function public.admin_set_availability(
  p_pin text,
  p_artist_id uuid,
  p_dato date,
  p_ledig boolean
)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if p_artist_id is null or p_dato is null or p_ledig is null then
    raise exception 'Artist og dato mangler';
  end if;

  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  if not exists (select 1 from public.artists where id = p_artist_id) then
    raise exception 'Fant ikke artisten';
  end if;

  if p_ledig and exists (
    select 1
    from public.gigs
    where artist_id = p_artist_id
      and dato = p_dato
  ) then
    raise exception 'Datoen er opptatt av en bekreftet jobb';
  end if;

  insert into public.availability (artist_id, dato, er_tilgjengelig)
  values (p_artist_id, p_dato, p_ledig)
  on conflict (artist_id, dato) do update
  set er_tilgjengelig = excluded.er_tilgjengelig;
end;
$$;
