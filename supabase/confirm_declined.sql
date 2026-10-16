-- Tillat admin å bekrefte en forespørsel selv om artisten har sagt nei.
-- Trygt å kjøre på nytt.

create or replace function public.admin_confirm_deal(p_pin text, p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
  gig_id uuid;
  artist_navn text;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  update public.bookings
  set status = 'confirmed',
      admin_signert_at = coalesce(admin_signert_at, now()),
      bekreftet_at = now(),
      presse_klar = true,
      reise_token = replace(gen_random_uuid()::text, '-', ''),
      dag_token = replace(gen_random_uuid()::text, '-', '')
  where id = p_booking_id
    and status in ('accepted', 'admin_signed', 'declined')
  returning * into booking;

  if not found then
    raise exception 'Forespørselen kan ikke bekreftes ennå';
  end if;

  update public.artist_offers
  set status = 'approved'
  where booking_id = booking.id
    and status in ('pending', 'declined');

  select id into gig_id from public.gigs where booking_id = booking.id;
  if gig_id is null then
    raise exception 'Konserten ble ikke opprettet';
  end if;

  select navn into artist_navn from public.artists where id = booking.artist_id;

  insert into public.gig_crew_travel (gig_id, member_id, navn, rolle, er_leder)
  select gig_id, m.id, m.navn, m.rolle, m.er_leder
  from public.band_members m
  join public.bands b on b.id = m.band_id
  where b.artist_id = booking.artist_id;

  if not found then
    insert into public.gig_crew_travel (gig_id, navn, rolle, er_leder)
    values (gig_id, coalesce(artist_navn, 'Artist'), 'Artist', true);
  end if;
end;
$$;
