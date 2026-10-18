-- Booking- og produksjonsportal for Amundsen Studio.
-- Kjør filen én gang i SQL-editoren i Supabase.
--
-- For å nullstille skjemaet:
-- drop table if exists public.setlists, public.repertoire, public.gigs, public.bookings, public.availability, public.artists cascade;
-- drop function if exists public.artist_me();
-- drop function if exists public.current_artist_id();
-- drop function if exists public.confirm_booking(uuid);
-- drop function if exists public.get_gig_by_token(text);
-- drop function if exists public.save_production_plan(text, jsonb);
-- drop function if exists public.gig_json(public.gigs, text);
-- drop function if exists public.gig_json(public.gigs);
-- drop function if exists public.booking_arrangor(public.bookings);
-- drop function if exists public.admin_set_availability(text, uuid, date, boolean);
-- drop function if exists public.admin_check_pin(text);
-- drop function if exists public.set_admin_pin(text);
-- drop table if exists private.admin_gate;
-- drop schema if exists private;

create table public.artists (
  id uuid primary key default gen_random_uuid(),
  navn text not null,
  tagline text not null,
  bio text not null,
  bilde_url text not null,
  video_url text not null,
  spotify_uri text not null default '',
  minstepris integer not null check (minstepris >= 0),
  publisert boolean not null default true,
  created_at timestamptz not null default now()
);

comment on column public.artists.minstepris is 'Minstepris i hele kroner.';
comment on column public.artists.video_url is 'Direkte lenke til et kort liveshow-klipp, omtrent 30 sekunder.';
comment on column public.artists.spotify_uri is 'spotify:artist:... eller en open.spotify.com-lenke.';

create table public.availability (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.artists (id) on delete cascade,
  dato date not null,
  er_tilgjengelig boolean not null,
  unique (artist_id, dato)
);

create index availability_artist_dato_idx on public.availability (artist_id, dato);

comment on column public.availability.er_tilgjengelig is 'true = ledig for booking, false = sperret av artisten.';

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.artists (id) on delete restrict,
  dato date not null,
  status text not null default 'inquiry' check (status in ('inquiry', 'declined', 'confirmed')),
  arrangor_navn text not null,
  organisasjon text not null,
  kontaktperson text not null,
  epost text not null,
  telefon text not null,
  spillested text not null,
  notater text not null default '',
  created_at timestamptz not null default now()
);

create index bookings_artist_dato_idx on public.bookings (artist_id, dato);

create unique index bookings_confirmed_artist_dato_idx
  on public.bookings (artist_id, dato)
  where status = 'confirmed';

comment on table public.bookings is 'Inngående bookingforespørsler. Nye rader fra portalen har status inquiry.';
comment on column public.bookings.id is 'Felles hendelses-ID. Gjenbrukes som gigs.booking_id fra forespørsel til kjøreplan.';

create table public.gigs (
  id uuid primary key default gen_random_uuid(),
  booking_token text not null unique,
  artist_id uuid not null references public.artists (id) on delete restrict,
  booking_id uuid not null unique references public.bookings (id) on delete restrict,
  dato date not null,
  status text not null check (status in ('confirmed', 'ready')),
  arrangor jsonb not null default '{}'::jsonb,
  produksjon jsonb not null default '{}'::jsonb,
  travel_status text not null default 'not_booked' check (travel_status in ('not_booked', 'booked')),
  arrival_time timestamptz,
  pickup_location text not null default '',
  departure_time timestamptz,
  dropoff_location text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index gigs_artist_dato_idx on public.gigs (artist_id, dato);

comment on column public.gigs.booking_id is 'Samme ID som bookingen. Artist, dato og arrangør hentes fra den raden.';
comment on column public.gigs.booking_token is 'Hemmelig nøkkel i lenken /production/:booking_token.';
comment on column public.gigs.arrangor is 'Speil av arrangørfeltene på bookingen, til artist-appen. Produksjonssiden leser feltene fra bookingen via booking_id.';
comment on column public.gigs.produksjon is 'Kjøreplan: arrangementsnavn, overnatting_navn, overnatting_adresse, flyplass, reiserute, get_in, lydprove, get_in_show, showstart, curfew, middag, load_out, middag_pa_overnatting, middag_sted, middag_adresse, tekniker_navn, tekniker_telefon, merknader.';
comment on column public.gigs.travel_status is 'not_booked til artisten har lagret ankomst og avreise. Da blir verdien booked.';
comment on column public.gigs.pickup_location is 'Hentested, for eksempel flyplass, selv om konserten er et annet sted.';
comment on column public.gigs.dropoff_location is 'Avleveringssted når artisten skal skysses tilbake.';

create or replace function public.bookings_require_available_date()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'inquiry' and not exists (
    select 1
    from public.artist_availability a
    join public.bands b on b.id = a.band_id
    where b.artist_id = new.artist_id
      and a.date = new.dato
      and a.status = 'available'
      and not exists (
        select 1
        from public.gigs g
        where g.artist_id = new.artist_id
          and g.dato = new.dato
      )
  ) then
    raise exception 'Datoen er ikke tilgjengelig for booking';
  end if;
  return new;
end;
$$;

create trigger bookings_require_available_date
before insert on public.bookings
for each row
execute function public.bookings_require_available_date();

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

create trigger bookings_sync_confirmed_gig
after insert or update on public.bookings
for each row
execute function public.bookings_sync_confirmed_gig();

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

alter table public.artists enable row level security;
alter table public.availability enable row level security;
alter table public.bookings enable row level security;
alter table public.gigs enable row level security;

create policy artists_public_read on public.artists
for select to anon, authenticated
using (publisert);

create policy availability_public_read on public.availability
for select to anon, authenticated
using (true);

create policy bookings_public_insert on public.bookings
for insert to anon, authenticated
with check (status = 'inquiry');

revoke all on table public.gigs from anon, authenticated;
grant select on table public.artists to anon, authenticated;
grant select on table public.availability to anon, authenticated;
grant insert on table public.bookings to anon, authenticated;

revoke all on function public.confirm_booking(uuid) from public, anon, authenticated;
grant execute on function public.confirm_booking(uuid) to service_role;
grant execute on function public.get_gig_by_token(text) to anon, authenticated;
grant execute on function public.save_production_plan(text, jsonb) to anon, authenticated;
revoke all on function public.booking_arrangor(public.bookings) from public, anon, authenticated;
revoke all on function public.gig_json(public.gigs) from public, anon, authenticated;
revoke all on function public.gigs_match_booking() from public, anon, authenticated;
revoke all on function public.bookings_guard_confirmed() from public, anon, authenticated;
grant execute on function public.bookings_sync_confirmed_gig() to anon, authenticated;

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

create table if not exists private.admin_gate (
  id boolean primary key default true,
  pin_hash text not null,
  constraint admin_gate_singleton check (id)
);

comment on table private.admin_gate is 'PIN-hash for /admin/kalender. Ikke lesbar for anon.';

create or replace function public.set_admin_pin(p_pin text)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if p_pin is null or length(trim(p_pin)) < 4 then
    raise exception 'PIN må ha minst 4 tegn';
  end if;

  insert into private.admin_gate (id, pin_hash)
  values (true, crypt(trim(p_pin), gen_salt('bf')))
  on conflict (id) do update
  set pin_hash = excluded.pin_hash;
end;
$$;

create or replace function public.admin_check_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  return exists (
    select 1
    from private.admin_gate
    where crypt(coalesce(p_pin, ''), pin_hash) = pin_hash
  );
end;
$$;

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

revoke all on function public.set_admin_pin(text) from public, anon, authenticated;
revoke all on function public.admin_check_pin(text) from public;
revoke all on function public.admin_set_availability(text, uuid, date, boolean) from public;
grant execute on function public.admin_check_pin(text) to anon, authenticated;
grant execute on function public.admin_set_availability(text, uuid, date, boolean) to anon, authenticated;

-- Artistportal: innlogging, repertoar og settliste.
-- Trygt å kjøre på nytt etter schema.sql.
--
-- Koble en innlogget bruker til en artist, som database-eier:
--   insert into private.artist_logins (artist_id, auth_user_id)
--   values ('<artist-uuid>', '<auth.users-uuid>');
--
-- I Supabase Auth: slå av åpen registrering, og legg nettstedets
-- /min-side til som tillatt redirect-URL for magisk lenke.

create schema if not exists private;

create table if not exists private.artist_logins (
  artist_id uuid primary key references public.artists (id) on delete cascade,
  auth_user_id uuid not null unique references auth.users (id) on delete cascade
);

comment on table private.artist_logins is 'Kobler en Supabase Auth-bruker til én artist. Ikke lesbar for nettleseren.';

revoke all on table private.artist_logins from public, anon, authenticated;

create table if not exists public.repertoire (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.artists (id) on delete cascade,
  tittel text not null,
  spilletid text not null check (spilletid ~ '^\d{2}:\d{2}$'),
  created_at timestamptz not null default now()
);

create index if not exists repertoire_artist_idx on public.repertoire (artist_id);

alter table public.repertoire drop column if exists opphaver;

comment on table public.repertoire is 'Artistens låtbank. Spilletid er mm:ss. Opphaver ligger i TONO.';

create table if not exists public.setlists (
  gig_id uuid primary key references public.gigs (id) on delete cascade,
  artist_id uuid not null references public.artists (id) on delete restrict,
  spor jsonb not null default '[]'::jsonb,
  tono_tekst text not null default '',
  bekreftet_at timestamptz,
  updated_at timestamptz not null default now()
);

comment on table public.setlists is 'Bekreftet settliste for én gig. tono_tekst er ferdig formatert til TONO.';
comment on column public.setlists.spor is 'Liste med tittel, spilletid, repertoire_id og ekstra, i spilleorden.';

create or replace function public.current_artist_id()
returns uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select artist_id
  from private.artist_logins
  where auth_user_id = auth.uid();
$$;

create or replace function public.artist_me()
returns jsonb
language sql
stable
security definer
set search_path = public, private
as $$
  select jsonb_build_object(
    'artist_id', a.id,
    'navn', a.navn,
    'epost', auth.jwt() ->> 'email'
  )
  from private.artist_logins l
  join public.artists a on a.id = l.artist_id
  where l.auth_user_id = auth.uid();
$$;

revoke all on function public.current_artist_id() from public, anon;
revoke all on function public.artist_me() from public, anon;
grant execute on function public.current_artist_id() to authenticated;
grant execute on function public.artist_me() to authenticated;

alter table public.repertoire enable row level security;
alter table public.setlists enable row level security;

drop policy if exists repertoire_owner on public.repertoire;
create policy repertoire_owner on public.repertoire
for all to authenticated
using (artist_id = public.current_artist_id())
with check (artist_id = public.current_artist_id());

drop policy if exists setlists_owner on public.setlists;
create policy setlists_owner on public.setlists
for all to authenticated
using (
  artist_id = public.current_artist_id()
  and exists (
    select 1 from public.gigs g
    where g.id = gig_id and g.artist_id = public.current_artist_id()
  )
)
with check (
  artist_id = public.current_artist_id()
  and exists (
    select 1 from public.gigs g
    where g.id = gig_id and g.artist_id = public.current_artist_id()
  )
);

drop policy if exists gigs_artist_read on public.gigs;
create policy gigs_artist_read on public.gigs
for select to authenticated
using (artist_id = public.current_artist_id());

grant select on table public.gigs to authenticated;
grant select, insert, update, delete on table public.repertoire to authenticated;
grant select, insert, update, delete on table public.setlists to authenticated;


-- Band, medlemmer, invitasjon og ridere.

-- Band, medlemmer og invitasjon uten manuelle ID-koder.
-- Trygt å kjøre på nytt etter schema.sql.
--
-- Bandlederen er brukeren som allerede er koblet i private.artist_logins.
-- Medlemmer aktiveres via lenken /min-side/invitasjon/<token>.
-- I Supabase Auth: tillat magisk lenke for nye brukere, og legg
-- https://<nettsted>/min-side/invitasjon/** inn som redirect-URL.

create table if not exists public.bands (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid unique references public.artists (id) on delete cascade,
  navn text not null,
  kontaktinfo text not null default '',
  tech_felles text not null default '',
  hospitality_felles text not null default '',
  input_liste text not null default '',
  monitor text not null default '',
  scenerigg text not null default '',
  pa_krav text not null default '',
  stage_plot_path text,
  stage_plot_name text,
  stage_plot_type text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.bands is 'Ett band per artist. tech_felles og hospitality_felles er felles rider, ikke kjøreplan.';

create table if not exists public.band_members (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  user_id uuid unique references auth.users (id) on delete cascade,
  navn text not null default '',
  rolle text not null default '',
  telefon text not null default '',
  mat text not null default '',
  tech_personlig text not null default '',
  er_leder boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists band_members_one_leader_idx
  on public.band_members (band_id)
  where er_leder;

comment on table public.band_members is 'Medlem eller crew. user_id peker på auth.users når kontoen er aktivert.';
comment on column public.band_members.rolle is 'Instrument eller rolle, for eksempel musiker, lydtekniker eller turnéleder.';
comment on column public.band_members.mat is 'Dietter, allergier og spesielle ønsker.';
comment on column public.band_members.tech_personlig is 'IEM, trådløse frekvenser, mikrofon, DI og strøm.';

create table if not exists public.band_invites (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  email text not null,
  rolle text not null,
  token text not null unique,
  invited_by uuid references auth.users (id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists band_invites_open_email_idx
  on public.band_invites (band_id, lower(email))
  where accepted_at is null;

comment on table public.band_invites is 'E-postinvitasjon. Tokenet i lenken aktiverer kontoen uten manuell ID.';

create or replace function public.current_artist_id()
returns uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select coalesce(
    (select artist_id from private.artist_logins where auth_user_id = auth.uid()),
    (
      select b.artist_id
      from public.band_members m
      join public.bands b on b.id = m.band_id
      where m.user_id = auth.uid()
    )
  );
$$;

create or replace function public.artist_me()
returns jsonb
language sql
stable
security definer
set search_path = public, private
as $$
  select jsonb_build_object(
    'artist_id', a.id,
    'navn', a.navn,
    'epost', auth.jwt() ->> 'email'
  )
  from public.artists a
  where a.id = public.current_artist_id();
$$;

create or replace function public.current_band_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select band_id from public.band_members where user_id = auth.uid();
$$;

create or replace function public.is_band_leader()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.band_members
    where user_id = auth.uid() and er_leder
  );
$$;

create or replace function public.is_band_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.band_members
    where user_id = auth.uid()
  );
$$;

create or replace function public.attach_band_leader()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  if exists (select 1 from public.band_members where user_id = auth.uid()) then
    return;
  end if;
  update public.band_members m
  set user_id = auth.uid()
  from public.bands b
  where m.band_id = b.id
    and m.er_leder
    and m.user_id is null
    and b.artist_id = (
      select artist_id from private.artist_logins where auth_user_id = auth.uid()
    );
end;
$$;

create or replace function public.create_band(p_navn text, p_kontakt text)
returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_artist uuid;
  v_band uuid;
  v_name text := nullif(trim(p_navn), '');
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt.';
  end if;
  if v_name is null then
    raise exception 'Bandet trenger et navn.';
  end if;
  if exists (select 1 from public.band_members where user_id = auth.uid()) then
    raise exception 'Du er allerede med i et band.';
  end if;
  v_artist := (
    select artist_id from private.artist_logins where auth_user_id = auth.uid()
  );
  if v_artist is not null and exists (select 1 from public.bands where artist_id = v_artist) then
    raise exception 'Bandet finnes allerede.';
  end if;
  insert into public.bands (artist_id, navn, kontaktinfo, created_by)
  values (v_artist, v_name, coalesce(trim(p_kontakt), ''), auth.uid())
  returning id into v_band;
  insert into public.band_members (band_id, user_id, navn, rolle, er_leder)
  values (v_band, auth.uid(), v_name, 'Bandleder', true);
  return v_band;
end;
$$;

create or replace function public.invite_band_member(p_email text, p_rolle text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_band uuid;
  v_email text := lower(trim(p_email));
  v_role text := nullif(trim(p_rolle), '');
  v_token text;
  v_id uuid;
begin
  if not public.is_band_member() then
    raise exception 'Du er ikke med i et band.';
  end if;
  if v_email is null or position('@' in v_email) = 0 then
    raise exception 'Oppgi en gyldig e-postadresse.';
  end if;
  if v_role is null then
    raise exception 'Oppgi en rolle.';
  end if;
  v_band := public.current_band_id();
  v_token := encode(gen_random_bytes(16), 'hex');
  select id into v_id
  from public.band_invites
  where band_id = v_band and lower(email) = v_email and accepted_at is null;
  if v_id is null then
    insert into public.band_invites (band_id, email, rolle, token, invited_by)
    values (v_band, v_email, v_role, v_token, auth.uid())
    returning id into v_id;
  else
    update public.band_invites
    set rolle = v_role, token = v_token, invited_by = auth.uid()
    where id = v_id;
  end if;
  return jsonb_build_object(
    'id', v_id,
    'band_id', v_band,
    'epost', v_email,
    'rolle', v_role,
    'token', v_token
  );
end;
$$;

create or replace function public.invite_preview(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'band_navn', b.navn,
    'epost', i.email,
    'rolle', i.rolle,
    'brukt', i.accepted_at is not null
  )
  from public.band_invites i
  join public.bands b on b.id = i.band_id
  where i.token = p_token;
$$;

create or replace function public.accept_band_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.band_invites;
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_member uuid;
begin
  if auth.uid() is null then
    raise exception 'Åpne lenken i e-posten for å aktivere kontoen.';
  end if;
  select * into v_invite from public.band_invites where token = p_token;
  if not found then
    raise exception 'Invitasjonen finnes ikke.';
  end if;
  if lower(v_invite.email) <> v_email then
    raise exception 'Lenken er sendt til en annen e-postadresse.';
  end if;
  if exists (
    select 1 from public.band_members
    where user_id = auth.uid() and band_id <> v_invite.band_id
  ) then
    raise exception 'Kontoen er allerede med i et annet band.';
  end if;
  insert into public.band_members (band_id, user_id, rolle)
  values (v_invite.band_id, auth.uid(), v_invite.rolle)
  on conflict (user_id) do update
    set rolle = coalesce(nullif(public.band_members.rolle, ''), excluded.rolle)
  returning id into v_member;
  update public.band_invites set accepted_at = now() where id = v_invite.id;
  return v_member;
end;
$$;

create or replace function public.riders_for_token(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', b.id,
    'artist_id', b.artist_id,
    'navn', b.navn,
    'kontaktinfo', b.kontaktinfo,
    'tech_felles', b.tech_felles,
    'hospitality_felles', b.hospitality_felles,
    'input_liste', b.input_liste,
    'monitor', b.monitor,
    'scenerigg', b.scenerigg,
    'pa_krav', b.pa_krav,
    'stage_plot_name', b.stage_plot_name,
    'stage_plot_type', b.stage_plot_type,
    'medlemmer', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'band_id', m.band_id,
          'navn', m.navn,
          'rolle', m.rolle,
          'telefon', m.telefon,
          'mat', m.mat,
          'tech_personlig', m.tech_personlig,
          'er_leder', m.er_leder
        )
        order by m.er_leder desc, m.navn
      )
      from public.band_members m
      where m.band_id = b.id
    ), '[]'::jsonb)
  )
  from public.gigs g
  join public.bands b on b.artist_id = g.artist_id
  where g.booking_token = p_token;
$$;

revoke all on function public.current_artist_id() from public, anon;
revoke all on function public.artist_me() from public, anon;
revoke all on function public.current_band_id() from public;
revoke all on function public.is_band_leader() from public;
revoke all on function public.is_band_member() from public;
revoke all on function public.attach_band_leader() from public;
revoke all on function public.create_band(text, text) from public;
revoke all on function public.invite_band_member(text, text) from public;
revoke all on function public.invite_preview(text) from public;
revoke all on function public.accept_band_invite(text) from public;
revoke all on function public.riders_for_token(text) from public;

grant execute on function public.current_artist_id() to authenticated;
grant execute on function public.artist_me() to authenticated;
grant execute on function public.current_band_id() to authenticated;
grant execute on function public.is_band_leader() to authenticated;
grant execute on function public.is_band_member() to authenticated;
grant execute on function public.attach_band_leader() to authenticated;
grant execute on function public.create_band(text, text) to authenticated;
grant execute on function public.invite_band_member(text, text) to authenticated;
grant execute on function public.invite_preview(text) to anon, authenticated;
grant execute on function public.accept_band_invite(text) to authenticated;
grant execute on function public.riders_for_token(text) to anon, authenticated;

alter table public.bands enable row level security;
alter table public.band_members enable row level security;
alter table public.band_invites enable row level security;

drop policy if exists bands_member_read on public.bands;
create policy bands_member_read on public.bands
for select to authenticated
using (id = public.current_band_id());

drop policy if exists bands_leader_update on public.bands;
drop policy if exists bands_member_update on public.bands;
create policy bands_member_update on public.bands
for update to authenticated
using (id = public.current_band_id() and public.is_band_member())
with check (id = public.current_band_id() and public.is_band_member());

drop policy if exists band_members_read on public.band_members;
create policy band_members_read on public.band_members
for select to authenticated
using (band_id = public.current_band_id());

drop policy if exists band_members_self_update on public.band_members;
create policy band_members_self_update on public.band_members
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and band_id = public.current_band_id());

drop policy if exists band_invites_leader_read on public.band_invites;
drop policy if exists band_invites_member_read on public.band_invites;
create policy band_invites_member_read on public.band_invites
for select to authenticated
using (band_id = public.current_band_id() and public.is_band_member());

drop policy if exists band_invites_leader_delete on public.band_invites;
drop policy if exists band_invites_member_delete on public.band_invites;
create policy band_invites_member_delete on public.band_invites
for delete to authenticated
using (band_id = public.current_band_id() and public.is_band_member() and accepted_at is null);

grant select, update on table public.bands to authenticated;
grant select on table public.band_members to authenticated;
grant update (navn, rolle, telefon, mat, tech_personlig) on table public.band_members to authenticated;
grant select, delete on table public.band_invites to authenticated;

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


-- Tilgjengelighetskalender. Samme innhold som supabase/artist_availability.sql.
-- Tilgjengelighetskalender styrt av bandet. Uten rad er datoen utilgjengelig.
-- Kjør denne hvis schema.sql allerede er lagt inn uten tabellen.

create table if not exists public.artist_availability (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  date date not null,
  status text not null check (status in ('available', 'unavailable')),
  unique (band_id, date)
);

comment on table public.artist_availability is 'Datoer bandet har markert. Ingen rad betyr utilgjengelig.';
comment on column public.artist_availability.status is 'available eller unavailable. Bekreftede jobber låses av gigs, uavhengig av raden.';

alter table public.artist_availability enable row level security;

drop policy if exists artist_availability_member_write on public.artist_availability;
create policy artist_availability_member_write on public.artist_availability
for all to authenticated
using (
  exists (
    select 1 from public.band_members m
    where m.band_id = artist_availability.band_id
      and m.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.band_members m
    where m.band_id = artist_availability.band_id
      and m.user_id = auth.uid()
  )
);

drop policy if exists artist_availability_public_read on public.artist_availability;
create policy artist_availability_public_read on public.artist_availability
for select to anon
using (status = 'available');

grant select, insert, update, delete on table public.artist_availability to authenticated;
grant select on table public.artist_availability to anon;

create or replace function public.availability_for_artist(
  p_artist_id uuid,
  p_from date,
  p_to date
)
returns table (dato date, er_tilgjengelig boolean, er_booket boolean)
language sql
stable
security definer
set search_path = public
as $$
  select a.date, true, false
  from public.artist_availability a
  join public.bands b on b.id = a.band_id
  where b.artist_id = p_artist_id
    and a.status = 'available'
    and a.date between p_from and p_to
    and not exists (
      select 1
      from public.gigs g
      where g.artist_id = p_artist_id
        and g.dato = a.date
    )
  union all
  select g.dato, false, true
  from public.gigs g
  where g.artist_id = p_artist_id
    and g.dato between p_from and p_to;
$$;

create or replace function public.save_artist_availability(
  p_dates date[],
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_band uuid;
begin
  if auth.uid() is null then
    raise exception 'Logg inn for å endre kalenderen';
  end if;
  if p_status not in ('available', 'unavailable') then
    raise exception 'Ugyldig status';
  end if;
  if p_dates is null or cardinality(p_dates) = 0 then
    return;
  end if;

  v_band := public.current_band_id();
  if v_band is null then
    raise exception 'Opprett bandet før du åpner kalenderen.';
  end if;
  if not exists (
    select 1 from public.band_members
    where band_id = v_band and user_id = auth.uid()
  ) then
    raise exception 'Bare bandet kan endre tilgjengeligheten';
  end if;

  if p_status = 'available' and exists (
    select 1
    from unnest(p_dates) as d
    join public.bands b on b.id = v_band
    join public.gigs g on g.artist_id = b.artist_id and g.dato = d
  ) then
    raise exception 'Datoen er opptatt av en bekreftet jobb';
  end if;

  insert into public.artist_availability (band_id, date, status)
  select v_band, d, p_status
  from unnest(p_dates) as d
  on conflict (band_id, date) do update
  set status = excluded.status;
end;
$$;

create or replace function public.bookings_require_available_date()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'inquiry' and not exists (
    select 1
    from public.artist_availability a
    join public.bands b on b.id = a.band_id
    where b.artist_id = new.artist_id
      and a.date = new.dato
      and a.status = 'available'
      and not exists (
        select 1
        from public.gigs g
        where g.artist_id = new.artist_id
          and g.dato = new.dato
      )
  ) then
    raise exception 'Datoen er ikke tilgjengelig for booking';
  end if;
  return new;
end;
$$;

revoke all on function public.availability_for_artist(uuid, date, date) from public;
grant execute on function public.availability_for_artist(uuid, date, date) to anon, authenticated;
revoke all on function public.save_artist_availability(date[], text) from public, anon;
grant execute on function public.save_artist_availability(date[], text) to authenticated;


-- Rider-PDF og scenekart. Samme innhold som supabase/rider_pdf.sql.

-- Teknisk rider, scenekart og PDF-eksport.
-- Trygt å kjøre på nytt etter schema.sql.

alter table public.bands
  add column if not exists input_liste text not null default '',
  add column if not exists monitor text not null default '',
  add column if not exists scenerigg text not null default '',
  add column if not exists pa_krav text not null default '',
  add column if not exists stage_plot_path text,
  add column if not exists stage_plot_name text,
  add column if not exists stage_plot_type text;

comment on column public.bands.input_liste is 'Inputliste og patch på den tekniske rideren.';
comment on column public.bands.monitor is 'Wedges og IEM for hele bandet.';
comment on column public.bands.scenerigg is 'DJ- og scenerigg.';
comment on column public.bands.pa_krav is 'Krav til PA.';
comment on column public.bands.stage_plot_path is 'Sti i bucket stage-plots. Tom når intet kart er lastet opp.';
comment on column public.bands.stage_plot_name is 'Opprinnelig filnavn på scenekartet.';
comment on column public.bands.stage_plot_type is 'MIME-type: image/png, image/jpeg, image/svg+xml eller application/pdf.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'stage-plots',
  'stage-plots',
  false,
  8388608,
  array['image/png', 'image/jpeg', 'image/svg+xml', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists stage_plots_member_read on storage.objects;
create policy stage_plots_member_read on storage.objects
for select to authenticated
using (
  bucket_id = 'stage-plots'
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_insert on storage.objects;
drop policy if exists stage_plots_member_insert on storage.objects;
create policy stage_plots_member_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_update on storage.objects;
drop policy if exists stage_plots_member_update on storage.objects;
create policy stage_plots_member_update on storage.objects
for update to authenticated
using (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
)
with check (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_delete on storage.objects;
drop policy if exists stage_plots_member_delete on storage.objects;
create policy stage_plots_member_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

create or replace function public.riders_for_token(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', b.id,
    'artist_id', b.artist_id,
    'navn', b.navn,
    'kontaktinfo', b.kontaktinfo,
    'tech_felles', b.tech_felles,
    'hospitality_felles', b.hospitality_felles,
    'input_liste', b.input_liste,
    'monitor', b.monitor,
    'scenerigg', b.scenerigg,
    'pa_krav', b.pa_krav,
    'stage_plot_name', b.stage_plot_name,
    'stage_plot_type', b.stage_plot_type,
    'medlemmer', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'band_id', m.band_id,
          'navn', m.navn,
          'rolle', m.rolle,
          'telefon', m.telefon,
          'mat', m.mat,
          'tech_personlig', m.tech_personlig,
          'er_leder', m.er_leder
        )
        order by m.er_leder desc, m.navn
      )
      from public.band_members m
      where m.band_id = b.id
    ), '[]'::jsonb)
  )
  from public.gigs g
  join public.bands b on b.artist_id = g.artist_id
  where g.booking_token = p_token;
$$;

revoke all on function public.riders_for_token(text) from public;
grant execute on function public.riders_for_token(text) to anon, authenticated;

-- Tilbud fra bookingansvarlig. Samme innhold som supabase/offers.sql.
create table if not exists public.artist_offers (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.artists (id) on delete cascade,
  dato date not null,
  honorar integer not null check (honorar >= 0),
  spillested text not null,
  arrangor_navn text not null,
  melding text not null default '',
  avslag_kommentar text not null default '',
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

-- Web Push til bandleder og admin.
-- Kjør filen hvis databasen allerede finnes. Nye installasjoner har det i schema.sql.
--
-- Arrangørens forespørsel er en rad i public.bookings med status inquiry.
-- Settlisten er uavklart når setlists.bekreftet_at er tom.
--
-- Etterpå:
-- 1. Deploy supabase/functions/send-push med --no-verify-jwt.
-- 2. Legg VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT og PUSH_DISPATCH_SECRET
--    inn som secrets. Nøkkelparet for demo ligger i supabase/.vapid.env.
-- 3. Fyll private.push_settings med offentlig nøkkel, funksjons-URL og samme hemmelighet.
-- 4. Aktiver pg_net og pg_cron, og kjør denne filen på nytt så timeren blir lagt inn.

create schema if not exists private;

create table if not exists public.user_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

create index if not exists user_push_subscriptions_user_idx
  on public.user_push_subscriptions (user_id);

comment on table public.user_push_subscriptions is
  'Web Push-abonnement for én enhet. Bare bandleder og admin får lagre raden.';

create table if not exists public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  url text not null,
  dedupe_key text not null unique,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

comment on table public.push_outbox is
  'Varsler som venter på utsending. Klienten leser ikke tabellen.';

create table if not exists private.push_settings (
  id boolean primary key default true check (id),
  vapid_public_key text not null default '',
  vapid_subject text not null default 'mailto:booking@amundsen.studio',
  dispatch_url text not null default '',
  dispatch_secret text not null default ''
);

insert into private.push_settings (id)
values (true)
on conflict (id) do nothing;

alter table public.user_push_subscriptions enable row level security;
alter table public.push_outbox enable row level security;

drop policy if exists user_push_subscriptions_read_own on public.user_push_subscriptions;
create policy user_push_subscriptions_read_own on public.user_push_subscriptions
for select to authenticated
using (user_id = auth.uid());

grant select on table public.user_push_subscriptions to authenticated;

create or replace function public.can_receive_band_push()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.band_members m
    where m.user_id = auth.uid()
  );
$$;

create or replace function public.push_recipient_ids(p_artist_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select distinct m.user_id
  from public.band_members m
  join public.bands b on b.id = m.band_id
  where b.artist_id = p_artist_id
    and m.user_id is not null;
$$;

create or replace function public.push_vapid_public_key()
returns text
language sql
stable
security definer
set search_path = public, private
as $$
  select vapid_public_key from private.push_settings where id;
$$;

create or replace function public.save_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.can_receive_band_push() then
    raise exception 'Du er ikke med i et band.';
  end if;
  if p_endpoint is null or p_endpoint !~ '^https://' or btrim(p_p256dh) = '' or btrim(p_auth) = '' then
    raise exception 'Ugyldig push-abonnement.';
  end if;

  delete from public.user_push_subscriptions
  where endpoint = p_endpoint
    and user_id <> auth.uid();

  insert into public.user_push_subscriptions (user_id, endpoint, p256dh, auth)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id,
        p256dh = excluded.p256dh,
        auth = excluded.auth;
end;
$$;

create or replace function public.delete_push_subscription(p_endpoint text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Logg inn for å skru av varsler.';
  end if;
  if p_endpoint is null or btrim(p_endpoint) = '' then
    delete from public.user_push_subscriptions where user_id = auth.uid();
  else
    delete from public.user_push_subscriptions
    where user_id = auth.uid()
      and endpoint = p_endpoint;
  end if;
end;
$$;

create or replace function public.booking_request_for_me(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if auth.uid() is null or not public.can_receive_band_push() then
    return null;
  end if;

  select jsonb_build_object(
    'id', b.id,
    'artist_navn', a.navn,
    'dato', b.dato,
    'arrangor_navn', b.arrangor_navn,
    'organisasjon', b.organisasjon,
    'kontaktperson', b.kontaktperson,
    'epost', b.epost,
    'telefon', b.telefon,
    'spillested', b.spillested,
    'notater', b.notater
  )
  into result
  from public.bookings b
  join public.artists a on a.id = b.artist_id
  where b.id = p_id
    and b.status = 'inquiry'
    and auth.uid() in (select public.push_recipient_ids(b.artist_id));

  return result;
end;
$$;

create or replace function public.dispatch_push_outbox()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  settings private.push_settings%rowtype;
begin
  select * into settings from private.push_settings where id;
  if settings.dispatch_url is null or btrim(settings.dispatch_url) = '' then
    return;
  end if;
  if settings.dispatch_secret is null or btrim(settings.dispatch_secret) = '' then
    return;
  end if;
  perform net.http_post(
    url := settings.dispatch_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', settings.dispatch_secret
    ),
    body := '{}'::jsonb
  );
exception
  when others then
    raise warning 'Push-utsending ble ikke startet: %', sqlerrm;
end;
$$;

create or replace function public.enqueue_booking_request_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient uuid;
  who text;
  when_label text;
begin
  if new.status is distinct from 'inquiry' then
    return new;
  end if;

  who := coalesce(nullif(btrim(new.arrangor_navn), ''), nullif(btrim(new.spillested), ''), 'En arrangør');
  when_label := to_char(new.dato, 'DD.MM.YYYY');

  for recipient in
    select r.user_id
    from public.push_recipient_ids(new.artist_id) as r(user_id)
    where exists (
      select 1
      from public.user_push_subscriptions s
      where s.user_id = r.user_id
    )
  loop
    insert into public.push_outbox (user_id, title, body, url, dedupe_key)
    values (
      recipient,
      'Ny bookingforespørsel!',
      who || ' har sendt en forespørsel for ' || when_label || '. Klikk for å se detaljer.',
      '/artist/foresporsler/' || new.id::text,
      'booking:' || new.id::text || ':' || recipient::text
    )
    on conflict (dedupe_key) do nothing;
  end loop;

  perform public.dispatch_push_outbox();
  return new;
exception
  when others then
    raise warning 'Push-varsel for booking ble ikke lagt i kø: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists bookings_enqueue_push on public.bookings;
create trigger bookings_enqueue_push
after insert on public.bookings
for each row
execute function public.enqueue_booking_request_push();

create or replace function public.enqueue_setlist_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  yesterday date;
  gig record;
  recipient uuid;
begin
  perform public.dispatch_push_outbox();

  if extract(hour from timezone('Europe/Oslo', now())) <> 10 then
    return;
  end if;

  yesterday := (timezone('Europe/Oslo', now()))::date - 1;

  for gig in
    select g.id, g.artist_id
    from public.gigs g
    left join public.setlists s on s.gig_id = g.id
    where g.dato = yesterday
      and (s.gig_id is null or s.bekreftet_at is null)
  loop
    for recipient in
      select r.user_id
      from public.push_recipient_ids(gig.artist_id) as r(user_id)
      where exists (
        select 1
        from public.user_push_subscriptions s
        where s.user_id = r.user_id
      )
    loop
      insert into public.push_outbox (user_id, title, body, url, dedupe_key)
      values (
        recipient,
        'Bekreft gårsdagens settliste',
        'Husket dere å bekrefte låtene fra konserten i går? Klikk for å godkjenne TONO-rapporten.',
        '/artist/gigs/' || gig.id::text || '/settliste',
        'setlist:' || gig.id::text || ':' || yesterday::text || ':' || recipient::text
      )
      on conflict (dedupe_key) do nothing;
    end loop;
  end loop;

  perform public.dispatch_push_outbox();
end;
$$;

revoke all on function public.can_receive_band_push() from public;
revoke all on function public.push_recipient_ids(uuid) from public;
revoke all on function public.push_vapid_public_key() from public;
revoke all on function public.save_push_subscription(text, text, text) from public;
revoke all on function public.delete_push_subscription(text) from public;
revoke all on function public.booking_request_for_me(uuid) from public;
revoke all on function public.dispatch_push_outbox() from public;
revoke all on function public.enqueue_booking_request_push() from public;
revoke all on function public.enqueue_setlist_reminders() from public;

grant execute on function public.can_receive_band_push() to authenticated;
grant execute on function public.push_vapid_public_key() to anon, authenticated;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;
grant execute on function public.delete_push_subscription(text) to authenticated;
grant execute on function public.booking_request_for_me(uuid) to authenticated;

do $cron$
begin
  if exists (select 1 from cron.job where jobname = 'lavdi-push-hourly') then
    perform cron.unschedule('lavdi-push-hourly');
  end if;
  perform cron.schedule(
    'lavdi-push-hourly',
    '0 * * * *',
    'select public.enqueue_setlist_reminders()'
  );
exception
  when others then
    raise notice 'pg_cron er ikke aktivert, så påminnelsen kl. 10 ble ikke lagt inn: %', sqlerrm;
end;
$cron$;

-- Pressepakke og spillestedslogg.
-- Kjør filen hvis databasen allerede finnes. Nye installasjoner har det i schema.sql.
--
-- Musikklenken ligger fortsatt på artists.spotify_uri.
-- Pressebildene ligger i bucket press-kits.

create or replace function public.artist_slug(p_navn text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(
    lower(translate(coalesce(p_navn, ''), 'æøåÆØÅéÉáÁ&', 'aoaaoaeeaa ')),
    '[^a-z0-9]+',
    '-',
    'g'
  ));
$$;

create table if not exists public.band_press_kit (
  band_id uuid primary key references public.bands (id) on delete cascade,
  bio text not null default '',
  press_photo_1 text not null default '',
  press_photo_2 text not null default '',
  press_photo_3 text not null default '',
  updated_at timestamptz not null default now()
);

comment on table public.band_press_kit is
  'Offisiell pressepakke for bandet. Spotify-lenken hentes fra artisten.';
comment on column public.band_press_kit.press_photo_1 is 'Sti i bucket press-kits.';
comment on column public.band_press_kit.press_photo_2 is 'Sti i bucket press-kits.';
comment on column public.band_press_kit.press_photo_3 is 'Sti i bucket press-kits.';

create table if not exists public.venue_notes (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  venue_name text not null,
  city text not null default '',
  load_in_notes text not null default '',
  sound_lighting_notes text not null default '',
  hospitality_notes text not null default '',
  contact_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists venue_notes_band_venue_idx
  on public.venue_notes (band_id, lower(venue_name));

comment on table public.venue_notes is
  'Interne notater om spillested og arrangør. Bare bandets medlemmer kan lese dem.';

create or replace function public.touch_press_and_notes()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists band_press_kit_touch on public.band_press_kit;
create trigger band_press_kit_touch
before update on public.band_press_kit
for each row
execute function public.touch_press_and_notes();

drop trigger if exists venue_notes_touch on public.venue_notes;
create trigger venue_notes_touch
before update on public.venue_notes
for each row
execute function public.touch_press_and_notes();

alter table public.band_press_kit enable row level security;
alter table public.venue_notes enable row level security;

drop policy if exists band_press_kit_public_read on public.band_press_kit;
create policy band_press_kit_public_read on public.band_press_kit
for select to anon, authenticated
using (true);

drop policy if exists band_press_kit_member_insert on public.band_press_kit;
create policy band_press_kit_member_insert on public.band_press_kit
for insert to authenticated
with check (band_id = public.current_band_id());

drop policy if exists band_press_kit_member_update on public.band_press_kit;
create policy band_press_kit_member_update on public.band_press_kit
for update to authenticated
using (band_id = public.current_band_id())
with check (band_id = public.current_band_id());

drop policy if exists band_press_kit_member_delete on public.band_press_kit;
create policy band_press_kit_member_delete on public.band_press_kit
for delete to authenticated
using (band_id = public.current_band_id());

drop policy if exists venue_notes_member_all on public.venue_notes;
create policy venue_notes_member_all on public.venue_notes
for all to authenticated
using (band_id = public.current_band_id())
with check (band_id = public.current_band_id());

grant select on table public.band_press_kit to anon, authenticated;
grant insert, update, delete on table public.band_press_kit to authenticated;
grant select, insert, update, delete on table public.venue_notes to authenticated;

create or replace function public.press_kit_for_slug(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'artist_id', a.id,
    'navn', a.navn,
    'slug', public.artist_slug(a.navn),
    'bio', coalesce(k.bio, ''),
    'spotify_uri', a.spotify_uri,
    'press_photo_1', coalesce(k.press_photo_1, ''),
    'press_photo_2', coalesce(k.press_photo_2, ''),
    'press_photo_3', coalesce(k.press_photo_3, '')
  )
  from public.artists a
  left join public.bands b on b.artist_id = a.id
  left join public.band_press_kit k on k.band_id = b.id
  where a.publisert
    and (
      public.artist_slug(a.navn) = lower(btrim(p_slug))
      or a.id::text = btrim(p_slug)
    )
  limit 1;
$$;

revoke all on function public.artist_slug(text) from public;
revoke all on function public.press_kit_for_slug(text) from public;
grant execute on function public.artist_slug(text) to anon, authenticated;
grant execute on function public.press_kit_for_slug(text) to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'press-kits',
  'press-kits',
  true,
  20971520,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists press_kits_public_read on storage.objects;
create policy press_kits_public_read on storage.objects
for select to anon, authenticated
using (bucket_id = 'press-kits');

drop policy if exists press_kits_member_insert on storage.objects;
create policy press_kits_member_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'press-kits'
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists press_kits_member_update on storage.objects;
create policy press_kits_member_update on storage.objects
for update to authenticated
using (
  bucket_id = 'press-kits'
  and (storage.foldername(name))[1] = public.current_band_id()::text
)
with check (
  bucket_id = 'press-kits'
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists press_kits_member_delete on storage.objects;
create policy press_kits_member_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'press-kits'
  and (storage.foldername(name))[1] = public.current_band_id()::text
);
