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
