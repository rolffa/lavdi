-- Arkiverte forespørsler skal forsvinne fra artistportalen.
-- Trygt å kjøre på nytt.

alter table public.artist_offers drop constraint if exists artist_offers_status_check;
alter table public.artist_offers
  add constraint artist_offers_status_check
  check (status in ('pending', 'approved', 'declined', 'archived'));

create or replace function public.admin_archive_deal(p_pin text, p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  update public.bookings
  set arkivert_at = coalesce(arkivert_at, now())
  where id = p_booking_id
    and status = 'declined';

  if not found then
    raise exception 'Bare avslåtte forespørsler kan arkiveres';
  end if;

  update public.artist_offers
  set status = 'archived'
  where booking_id = p_booking_id
    and status = 'declined';
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

-- Rydd allerede arkiverte bookinger som fortsatt ligger som declined hos artisten.
update public.artist_offers o
set status = 'archived'
from public.bookings b
where o.booking_id = b.id
  and b.arkivert_at is not null
  and o.status = 'declined';
