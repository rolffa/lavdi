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
