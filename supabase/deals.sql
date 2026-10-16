-- Avtaleflyt: forespørsel til admin, 48 timer hos artist, signering, arrangørskjema.
-- Kjør filen hvis databasen allerede finnes.

alter table public.bookings drop constraint if exists bookings_status_check;
alter table public.bookings add constraint bookings_status_check
  check (status in (
    'inquiry',
    'with_artist',
    'declined',
    'accepted',
    'admin_signed',
    'confirmed'
  ));

alter table public.bookings add column if not exists honorar integer;
alter table public.bookings add column if not exists melding text not null default '';
alter table public.bookings add column if not exists avslag_kommentar text not null default '';
alter table public.bookings add column if not exists sendt_artist_at timestamptz;
alter table public.bookings add column if not exists svarfrist timestamptz;
alter table public.bookings add column if not exists admin_signert_at timestamptz;
alter table public.bookings add column if not exists bekreftet_at timestamptz;
alter table public.bookings add column if not exists presse_klar boolean not null default false;
alter table public.bookings add column if not exists reise_token text;
alter table public.bookings add column if not exists dag_token text;
alter table public.bookings add column if not exists reiserute text not null default '';
alter table public.bookings add column if not exists flyplass text not null default '';
alter table public.bookings add column if not exists avstand text not null default '';
alter table public.bookings add column if not exists oppmote text not null default '';
alter table public.bookings add column if not exists dagskjema boolean not null default false;
alter table public.bookings add column if not exists hotell_navn text not null default '';
alter table public.bookings add column if not exists hotell_adresse text not null default '';
alter table public.bookings add column if not exists get_in text not null default '';
alter table public.bookings add column if not exists lydprove text not null default '';
alter table public.bookings add column if not exists showstart text not null default '';
alter table public.bookings add column if not exists middag_sted text not null default '';
alter table public.bookings add column if not exists dag_notater text not null default '';
alter table public.bookings add column if not exists arkivert_at timestamptz;

create unique index if not exists bookings_reise_token_idx
  on public.bookings (reise_token) where reise_token is not null;
create unique index if not exists bookings_dag_token_idx
  on public.bookings (dag_token) where dag_token is not null;

alter table public.artist_offers add column if not exists booking_id uuid references public.bookings (id) on delete cascade;
alter table public.artist_offers add column if not exists svarfrist timestamptz;

create table if not exists public.gig_crew_travel (
  id uuid primary key default gen_random_uuid(),
  gig_id uuid not null references public.gigs (id) on delete cascade,
  member_id uuid,
  navn text not null,
  rolle text not null default '',
  er_leder boolean not null default false,
  aktiv boolean not null default true,
  bestilt boolean not null default false,
  arrival_time timestamptz,
  departure_time timestamptz,
  pickup_location text not null default '',
  dropoff_location text not null default ''
);

create index if not exists gig_crew_travel_gig_idx on public.gig_crew_travel (gig_id);

alter table public.gig_crew_travel enable row level security;
revoke all on table public.gig_crew_travel from anon, authenticated;

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

  -- Skjul fra artistportalen med en gang (my_offers viser bare pending/declined).
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

create or replace function public.admin_send_to_artist(
  p_pin text,
  p_booking_id uuid,
  p_honorar integer,
  p_melding text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
  deadline timestamptz;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if p_honorar is null or p_honorar < 0 then
    raise exception 'Honorar må være 0 eller høyere';
  end if;

  select * into booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Forespørselen finnes ikke';
  end if;

  if booking.status not in ('inquiry', 'declined')
     and not (booking.status = 'with_artist' and booking.svarfrist is not null and booking.svarfrist <= now()) then
    raise exception 'Forespørselen kan ikke sendes til artisten nå';
  end if;

  if exists (
    select 1 from public.gigs where artist_id = booking.artist_id and dato = booking.dato
  ) then
    raise exception 'Artisten er allerede booket denne datoen';
  end if;

  deadline := now() + interval '48 hours';

  update public.bookings
  set honorar = p_honorar,
      melding = trim(coalesce(p_melding, '')),
      status = 'with_artist',
      avslag_kommentar = '',
      arkivert_at = null,
      sendt_artist_at = now(),
      svarfrist = deadline
  where id = booking.id;

  update public.artist_offers
  set status = 'declined'
  where booking_id = booking.id
    and status = 'pending';

  insert into public.artist_offers (
    artist_id, dato, honorar, spillested, arrangor_navn, melding, status, booking_id, svarfrist
  )
  values (
    booking.artist_id,
    booking.dato,
    p_honorar,
    booking.spillested,
    booking.arrangor_navn,
    trim(coalesce(p_melding, '')),
    'pending',
    booking.id,
    deadline
  );
end;
$$;

create or replace function public.admin_sign_deal(p_pin text, p_booking_id uuid)
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
  set status = 'admin_signed',
      admin_signert_at = now()
  where id = p_booking_id
    and status = 'accepted';
  if not found then
    raise exception 'Artisten må si ja før kontrakten kan signeres';
  end if;
end;
$$;

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

  if offer.svarfrist is not null and offer.svarfrist <= now() then
    raise exception 'Svarfristen på 48 timer er ute';
  end if;

  if not coalesce(p_approve, false) then
    if length(trim(coalesce(p_comment, ''))) = 0 then
      raise exception 'Skriv hvorfor forespørselen avslås';
    end if;
    update public.artist_offers
    set status = 'declined',
        avslag_kommentar = trim(p_comment)
    where id = offer.id;
    if offer.booking_id is not null then
      update public.bookings
      set status = 'declined',
          avslag_kommentar = trim(p_comment)
      where id = offer.booking_id;
    end if;
    return;
  end if;

  if offer.booking_id is not null then
    update public.artist_offers set status = 'approved' where id = offer.id;
    update public.bookings set status = 'accepted' where id = offer.booking_id and status = 'with_artist';
    if not found then
      raise exception 'Forespørselen finnes ikke';
    end if;
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
    artist_id, dato, status, arrangor_navn, organisasjon, kontaktperson,
    epost, telefon, spillested, notater, honorar, melding, admin_signert_at, bekreftet_at, presse_klar
  )
  values (
    offer.artist_id, offer.dato, 'confirmed', offer.arrangor_navn, offer.arrangor_navn,
    '', '', '', offer.spillested, note, offer.honorar, offer.melding, now(), now(), true
  );

  update public.artist_offers set status = 'approved' where id = offer.id;
end;
$$;

create table if not exists public.mail_outbox (
  id uuid primary key default gen_random_uuid(),
  to_email text not null,
  subject text not null,
  body text not null,
  url text not null default '',
  dedupe_key text not null unique,
  created_at timestamptz not null default now()
);

alter table public.mail_outbox enable row level security;
revoke all on table public.mail_outbox from anon, authenticated;

create or replace function public.band_leader_emails(p_artist_id uuid)
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select distinct lower(btrim(u.email))
  from public.band_members m
  join public.bands b on b.id = m.band_id
  join auth.users u on u.id = m.user_id
  where b.artist_id = p_artist_id
    and u.email is not null
    and btrim(u.email) <> ''
    and (
      m.er_leder
      or lower(btrim(m.rolle)) = 'bandleder'
    );
$$;

revoke all on function public.band_leader_emails(uuid) from public;

create or replace function public.enqueue_booking_request_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient text;
  who text;
  when_label text;
begin
  if tg_op = 'INSERT' or new.status is distinct from 'with_artist' then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and old.status = 'with_artist'
     and old.svarfrist is not distinct from new.svarfrist then
    return new;
  end if;

  who := coalesce(nullif(btrim(new.arrangor_navn), ''), nullif(btrim(new.spillested), ''), 'En arrangør');
  when_label := to_char(new.dato, 'DD.MM.YYYY');

  for recipient in
    select public.band_leader_emails(new.artist_id)
  loop
    insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
    values (
      recipient,
      'Ny bookingforespørsel!',
      who || ' har sendt en forespørsel for ' || when_label || '. Klikk for å se detaljer.',
      '/min-side',
      'offer:' || new.id::text || ':' || coalesce(new.svarfrist::text, '') || ':' || recipient
    )
    on conflict (dedupe_key) do nothing;
  end loop;

  return new;
exception
  when others then
    raise warning 'E-post til bandleder ble ikke lagt i kø: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists bookings_enqueue_push on public.bookings;
create trigger bookings_enqueue_push
after insert or update of status, svarfrist on public.bookings
for each row
execute function public.enqueue_booking_request_push();

create or replace function public.booking_request_for_me(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return null;
end;
$$;

create or replace function public.organizer_travel_form(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
begin
  select * into booking
  from public.bookings
  where reise_token = p_token
    and status = 'confirmed';
  if not found then
    return null;
  end if;
  return public.deal_json(booking);
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

create or replace function public.organizer_day_form(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
begin
  select * into booking
  from public.bookings
  where dag_token = p_token
    and status = 'confirmed';
  if not found then
    return null;
  end if;
  return public.deal_json(booking);
end;
$$;

create or replace function public.save_organizer_day(
  p_token text,
  p_get_in text,
  p_soundcheck text,
  p_show text,
  p_dinner text,
  p_hotel_name text,
  p_hotel_address text,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  booking public.bookings%rowtype;
begin
  if length(trim(coalesce(p_hotel_address, ''))) = 0 then
    raise exception 'Adressen til overnattingsstedet må fylles ut';
  end if;
  update public.bookings
  set get_in = trim(coalesce(p_get_in, '')),
      lydprove = trim(coalesce(p_soundcheck, '')),
      showstart = trim(coalesce(p_show, '')),
      middag_sted = trim(coalesce(p_dinner, '')),
      hotell_navn = trim(coalesce(p_hotel_name, '')),
      hotell_adresse = trim(p_hotel_address),
      dag_notater = trim(coalesce(p_notes, '')),
      dagskjema = true
  where dag_token = p_token
    and status = 'confirmed'
  returning * into booking;
  if not found then
    raise exception 'Lenken finnes ikke';
  end if;
  update public.gigs
  set produksjon = produksjon || jsonb_build_object(
        'get_in', booking.get_in,
        'lydprove', booking.lydprove,
        'showstart', booking.showstart,
        'middag_sted', booking.middag_sted,
        'overnatting_navn', booking.hotell_navn,
        'overnatting_adresse', booking.hotell_adresse,
        'merknader', booking.dag_notater,
        'dagskjema', true
      ),
      updated_at = now()
  where booking_id = booking.id;
end;
$$;

create or replace function public.my_crew_travel(p_gig_id uuid)
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
  if not exists (
    select 1 from public.gigs
    where id = p_gig_id and artist_id = public.current_artist_id()
  ) then
    raise exception 'Fant ikke konserten.';
  end if;
  return coalesce((
    select jsonb_agg(
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
    )
    from public.gig_crew_travel c
    where c.gig_id = p_gig_id
  ), '[]'::jsonb);
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

create or replace function public.set_crew_member_active(
  p_gig_id uuid,
  p_member_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt';
  end if;
  if not exists (
    select 1
    from public.band_members m
    join public.bands b on b.id = m.band_id
    join public.gigs g on g.artist_id = b.artist_id
    where g.id = p_gig_id
      and m.user_id = auth.uid()
      and m.er_leder
  ) then
    raise exception 'Bare bandlederen kan endre hvem som er med';
  end if;
  if not coalesce(p_active, false) and (
    select count(*) from public.gig_crew_travel
    where gig_id = p_gig_id and aktiv and id <> p_member_id
  ) = 0 then
    raise exception 'Minst én person må være med på konserten';
  end if;
  update public.gig_crew_travel
  set aktiv = coalesce(p_active, false),
      bestilt = case when coalesce(p_active, false) then bestilt else false end
  where id = p_member_id and gig_id = p_gig_id;
  if not found then
    raise exception 'Fant ikke medlemmet';
  end if;
  return public.my_crew_travel(p_gig_id);
end;
$$;

revoke all on function public.admin_list_deals(text) from public;
grant execute on function public.admin_list_deals(text) to anon, authenticated;
revoke all on function public.admin_list_archived_deals(text) from public;
grant execute on function public.admin_list_archived_deals(text) to anon, authenticated;
revoke all on function public.admin_archive_deal(text, uuid) from public;
grant execute on function public.admin_archive_deal(text, uuid) to anon, authenticated;
revoke all on function public.admin_unarchive_deal(text, uuid) from public;
grant execute on function public.admin_unarchive_deal(text, uuid) to anon, authenticated;
revoke all on function public.admin_send_to_artist(text, uuid, integer, text) from public;
grant execute on function public.admin_send_to_artist(text, uuid, integer, text) to anon, authenticated;
revoke all on function public.admin_sign_deal(text, uuid) from public;
grant execute on function public.admin_sign_deal(text, uuid) to anon, authenticated;
revoke all on function public.admin_confirm_deal(text, uuid) from public;
grant execute on function public.admin_confirm_deal(text, uuid) to anon, authenticated;
revoke all on function public.organizer_travel_form(text) from public;
grant execute on function public.organizer_travel_form(text) to anon, authenticated;
revoke all on function public.save_organizer_travel(text, text, text, text) from public;
grant execute on function public.save_organizer_travel(text, text, text, text) to anon, authenticated;
revoke all on function public.organizer_day_form(text) from public;
grant execute on function public.organizer_day_form(text) to anon, authenticated;
revoke all on function public.save_organizer_day(text, text, text, text, text, text, text, text) from public;
grant execute on function public.save_organizer_day(text, text, text, text, text, text, text, text) to anon, authenticated;
revoke all on function public.my_crew_travel(uuid) from public;
grant execute on function public.my_crew_travel(uuid) to authenticated;
revoke all on function public.save_crew_travel(uuid, uuid, timestamptz, timestamptz, text, text) from public;
grant execute on function public.save_crew_travel(uuid, uuid, timestamptz, timestamptz, text, text) to authenticated;
revoke all on function public.set_crew_member_active(uuid, uuid, boolean) from public;
grant execute on function public.set_crew_member_active(uuid, uuid, boolean) to authenticated;

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
declare
  booking_id uuid;
  deadline timestamptz;
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
    select 1 from public.gigs where artist_id = p_artist_id and dato = p_dato
  ) then
    raise exception 'Artisten er allerede booket denne datoen';
  end if;
  if exists (
    select 1 from public.artist_offers
    where artist_id = p_artist_id and dato = p_dato and status = 'pending'
  ) then
    raise exception 'Det ligger allerede et tilbud på denne datoen';
  end if;

  deadline := now() + interval '48 hours';
  insert into public.bookings (
    artist_id, dato, status, arrangor_navn, organisasjon, kontaktperson,
    epost, telefon, spillested, notater, honorar, melding, sendt_artist_at, svarfrist
  )
  values (
    p_artist_id, p_dato, 'with_artist', trim(p_arrangor), trim(p_arrangor),
    '', '', '', trim(p_spillested), '', p_honorar, trim(coalesce(p_melding, '')), now(), deadline
  )
  returning id into booking_id;

  insert into public.artist_offers (
    artist_id, dato, honorar, spillested, arrangor_navn, melding, status, booking_id, svarfrist
  )
  values (
    p_artist_id, p_dato, p_honorar, trim(p_spillested), trim(p_arrangor),
    trim(coalesce(p_melding, '')), 'pending', booking_id, deadline
  );
end;
$$;

alter table private.admin_gate
  add column if not exists username text not null default 'admin';

create or replace function public.admin_sign_in(p_username text, p_password text)
returns boolean
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  return exists (
    select 1
    from private.admin_gate
    where lower(username) = lower(trim(coalesce(p_username, '')))
      and crypt(coalesce(p_password, ''), pin_hash) = pin_hash
  );
end;
$$;

revoke all on function public.admin_sign_in(text, text) from public;
grant execute on function public.admin_sign_in(text, text) to anon, authenticated;

