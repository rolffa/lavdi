-- Arrangør fyller flyplass + avstand (+ valgfri mer info) før artisten bestiller reise.
-- Ved første innsending legges e-post til bandleder i mail_outbox.
-- Trygt å kjøre på nytt.

alter table public.bookings
  add column if not exists avstand text not null default '';

comment on column public.bookings.avstand is
  'Avstand fra nærmeste flyplass til spillested. Fylles av arrangør før reisebestilling.';

create or replace function public.deal_json(p_booking public.bookings)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  artist_navn text;
  gig_id uuid;
  crew jsonb;
begin
  select navn into artist_navn from public.artists where id = p_booking.artist_id;
  select id into gig_id from public.gigs where booking_id = p_booking.id;
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
  where c.gig_id = gig_id;

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
    'gig_id', gig_id,
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

drop function if exists public.save_organizer_travel(text, text, text, text);

create or replace function public.save_organizer_travel(
  p_token text,
  p_airport text,
  p_distance text,
  p_route text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
  was_ready boolean;
  recipient text;
  when_label text;
  gig_id uuid;
begin
  if length(trim(coalesce(p_airport, ''))) = 0
     or length(trim(coalesce(p_distance, ''))) = 0 then
    raise exception 'Flyplass og avstand må fylles ut';
  end if;

  select * into booking
  from public.bookings
  where reise_token = p_token
    and status = 'confirmed'
  for update;
  if not found then
    raise exception 'Lenken finnes ikke';
  end if;

  was_ready := length(btrim(coalesce(booking.flyplass, ''))) > 0
    and length(btrim(coalesce(booking.avstand, ''))) > 0;

  update public.bookings
  set flyplass = trim(p_airport),
      avstand = trim(p_distance),
      reiserute = trim(coalesce(p_route, ''))
  where id = booking.id
  returning * into booking;

  update public.gigs
  set produksjon = produksjon || jsonb_build_object(
        'flyplass', booking.flyplass,
        'avstand', booking.avstand,
        'reiserute', booking.reiserute
      ),
      updated_at = now()
  where booking_id = booking.id
  returning id into gig_id;

  if not was_ready then
    when_label := to_char(booking.dato, 'DD.MM.YYYY');
    for recipient in
      select public.band_leader_emails(booking.artist_id)
    loop
      insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
      values (
        recipient,
        'Bestill reise',
        'Arrangøren har fylt ut reiseinfo for '
          || coalesce(nullif(btrim(booking.spillested), ''), 'konserten')
          || ' (' || when_label || '). Bestill reise i artistportalen.',
        case
          when gig_id is null then '/min-side'
          else '/artist/gigs/' || gig_id::text
        end,
        'travel:' || booking.id::text || ':' || recipient
      )
      on conflict (dedupe_key) do nothing;
    end loop;
  end if;
end;
$$;

create or replace function public.save_crew_travel(
  p_gig_id uuid,
  p_member_id uuid,
  p_arrival timestamptz,
  p_departure timestamptz,
  p_pickup text,
  p_dropoff text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  row public.gig_crew_travel%rowtype;
  leader boolean;
  airport text;
  distance text;
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt';
  end if;
  if length(trim(coalesce(p_pickup, ''))) = 0 or length(trim(coalesce(p_dropoff, ''))) = 0 then
    raise exception 'Ankomst, hentested, avreise og avleveringssted må fylles ut.';
  end if;

  select
    coalesce(b.flyplass, ''),
    coalesce(b.avstand, '')
  into airport, distance
  from public.gigs g
  left join public.bookings b on b.id = g.booking_id
  where g.id = p_gig_id;
  if length(btrim(airport)) = 0 or length(btrim(distance)) = 0 then
    raise exception 'Arrangøren må fylle ut flyplass og avstand før reisen kan bestilles.';
  end if;

  select * into row
  from public.gig_crew_travel
  where id = p_member_id and gig_id = p_gig_id and aktiv
  for update;
  if not found then
    raise exception 'Medlemmet er ikke med på denne konserten';
  end if;
  select exists (
    select 1
    from public.band_members m
    join public.bands b on b.id = m.band_id
    join public.gigs g on g.artist_id = b.artist_id
    where g.id = p_gig_id
      and m.user_id = auth.uid()
      and m.er_leder
  ) into leader;
  if not leader and row.member_id is distinct from (
    select m.id from public.band_members m where m.user_id = auth.uid() limit 1
  ) then
    raise exception 'Du kan bare fylle inn din egen reise';
  end if;
  update public.gig_crew_travel
  set arrival_time = p_arrival,
      departure_time = p_departure,
      pickup_location = trim(p_pickup),
      dropoff_location = trim(p_dropoff),
      bestilt = true
  where id = row.id;
  return public.my_crew_travel(p_gig_id);
end;
$$;

revoke all on function public.save_organizer_travel(text, text, text, text) from public;
grant execute on function public.save_organizer_travel(text, text, text, text) to anon, authenticated;
