-- Henting og reisedetaljer på den bekreftede gigen.
-- Kjør denne hvis schema.sql allerede er lagt inn uten disse kolonnene.

alter table public.gigs
  add column if not exists travel_status text not null default 'not_booked',
  add column if not exists arrival_time timestamptz,
  add column if not exists pickup_location text not null default '',
  add column if not exists departure_time timestamptz,
  add column if not exists dropoff_location text not null default '';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'gigs_travel_status_check'
  ) then
    alter table public.gigs
      add constraint gigs_travel_status_check
      check (travel_status in ('not_booked', 'booked'));
  end if;
end $$;

comment on column public.gigs.travel_status is 'not_booked til artisten har lagret ankomst og avreise. Da blir verdien booked.';
comment on column public.gigs.pickup_location is 'Hentested, for eksempel flyplass, selv om konserten er et annet sted.';
comment on column public.gigs.dropoff_location is 'Avleveringssted når artisten skal skysses tilbake.';

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

create or replace function public.save_gig_travel(
  p_gig_id uuid,
  p_arrival timestamptz,
  p_pickup text,
  p_departure timestamptz,
  p_dropoff text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated public.gigs%rowtype;
  pickup text := trim(coalesce(p_pickup, ''));
  dropoff text := trim(coalesce(p_dropoff, ''));
begin
  if auth.uid() is null then
    raise exception 'Logg inn for å lagre reisen';
  end if;
  if p_arrival is null or p_departure is null or pickup = '' or dropoff = '' then
    raise exception 'Ankomst, hentested, avreise og avleveringssted må fylles ut.';
  end if;

  update public.gigs
  set travel_status = 'booked',
      arrival_time = p_arrival,
      pickup_location = pickup,
      departure_time = p_departure,
      dropoff_location = dropoff,
      updated_at = now()
  where id = p_gig_id
    and artist_id = public.current_artist_id()
  returning * into updated;

  if not found then
    raise exception 'Fant ikke konserten.';
  end if;

  return public.gig_json(updated);
end;
$$;

revoke all on function public.save_gig_travel(uuid, timestamptz, text, timestamptz, text) from public, anon;
grant execute on function public.save_gig_travel(uuid, timestamptz, text, timestamptz, text) to authenticated;
