-- Arkiv for avslåtte forespørsler. Trygt å kjøre på nytt.
-- Krever admin_check_pin og deal_json fra deals.sql.

alter table public.bookings
  add column if not exists arkivert_at timestamptz;

comment on column public.bookings.arkivert_at is
  'Satt når admin arkiverer en avslått forespørsel.';

create or replace function public.deal_json(p_booking public.bookings)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  artist_navn text;
  v_gig_id uuid;
  crew jsonb;
begin
  select navn into artist_navn from public.artists where id = p_booking.artist_id;
  select id into v_gig_id from public.gigs where booking_id = p_booking.id;
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'member_id', c.id,
      'navn', c.navn,
      'rolle', c.rolle,
      'er_leder', c.er_leder,
      'aktiv', c.aktiv,
      'bestilt', c.bestilt,
      'arrival_time', c.arrival_time,
      'departure_time', c.departure_time,
      'pickup_location', c.pickup_location,
      'dropoff_location', c.dropoff_location
    )
    order by c.er_leder desc, c.navn
  ), '[]'::jsonb)
  into crew
  from public.gig_crew_travel c
  where c.gig_id = v_gig_id;

  return jsonb_build_object(
    'id', p_booking.id,
    'artist_id', p_booking.artist_id,
    'artist_navn', coalesce(artist_navn, ''),
    'dato', p_booking.dato,
    'arrangor_navn', p_booking.arrangor_navn,
    'organisasjon', p_booking.organisasjon,
    'kontaktperson', p_booking.kontaktperson,
    'epost', p_booking.epost,
    'telefon', p_booking.telefon,
    'spillested', p_booking.spillested,
    'notater', p_booking.notater,
    'honorar', p_booking.honorar,
    'melding', p_booking.melding,
    'status', p_booking.status,
    'avslag_kommentar', p_booking.avslag_kommentar,
    'sendt_artist_at', p_booking.sendt_artist_at,
    'svarfrist', p_booking.svarfrist,
    'admin_signert_at', p_booking.admin_signert_at,
    'gig_id', v_gig_id,
    'reise_token', coalesce(p_booking.reise_token, ''),
    'dag_token', coalesce(p_booking.dag_token, ''),
    'presse_klar', p_booking.presse_klar,
    'reiserute', p_booking.reiserute,
    'flyplass', p_booking.flyplass,
    'avstand', p_booking.avstand,
    'oppmote', p_booking.oppmote,
    'dagskjema', p_booking.dagskjema,
    'hotell_navn', p_booking.hotell_navn,
    'hotell_adresse', p_booking.hotell_adresse,
    'get_in', p_booking.get_in,
    'lydprove', p_booking.lydprove,
    'showstart', p_booking.showstart,
    'middag_sted', p_booking.middag_sted,
    'dag_notater', p_booking.dag_notater,
    'arkivert_at', p_booking.arkivert_at,
    'crew', crew
  );
end;
$$;

create or replace function public.admin_list_deals(p_pin text)
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
    select jsonb_agg(public.deal_json(b) order by b.dato)
    from public.bookings b
    where b.arkivert_at is null
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_list_archived_deals(p_pin text)
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
    select jsonb_agg(public.deal_json(b) order by b.arkivert_at desc nulls last)
    from public.bookings b
    where b.arkivert_at is not null
  ), '[]'::jsonb);
end;
$$;

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

create or replace function public.admin_unarchive_deal(p_pin text, p_booking_id uuid)
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
  set arkivert_at = null
  where id = p_booking_id
    and status = 'declined'
    and arkivert_at is not null;

  if not found then
    raise exception 'Forespørselen er ikke i arkivet';
  end if;

  update public.artist_offers
  set status = 'declined'
  where booking_id = p_booking_id
    and status = 'archived';
end;
$$;

revoke all on function public.admin_list_archived_deals(text) from public;
grant execute on function public.admin_list_archived_deals(text) to anon, authenticated;
revoke all on function public.admin_archive_deal(text, uuid) from public;
grant execute on function public.admin_archive_deal(text, uuid) to anon, authenticated;
revoke all on function public.admin_unarchive_deal(text, uuid) from public;
grant execute on function public.admin_unarchive_deal(text, uuid) to anon, authenticated;
