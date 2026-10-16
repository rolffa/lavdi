-- Skjul og publiser artistsider. Trygt å kjøre på nytt.
-- Krever at admin_check_pin finnes (fra admin_calendar.sql / deals.sql).

alter table public.artists
  add column if not exists publisert boolean not null default true;

comment on column public.artists.publisert is
  'false = skjult fra forsiden, artistside og offentlig pressepakke.';

drop policy if exists artists_public_read on public.artists;
create policy artists_public_read on public.artists
for select to anon, authenticated
using (publisert);

create or replace function public.admin_list_artists(p_pin text)
returns jsonb
language plpgsql
stable
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
        'id', a.id,
        'navn', a.navn,
        'tagline', a.tagline,
        'bio', a.bio,
        'bilde_url', a.bilde_url,
        'video_url', a.video_url,
        'spotify_uri', a.spotify_uri,
        'minstepris', a.minstepris,
        'publisert', a.publisert
      )
      order by a.navn
    )
    from public.artists a
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_set_artist_published(
  p_pin text,
  p_artist_id uuid,
  p_publisert boolean
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
  if p_artist_id is null or p_publisert is null then
    raise exception 'Artist mangler';
  end if;

  update public.artists
  set publisert = p_publisert
  where id = p_artist_id;

  if not found then
    raise exception 'Fant ikke artisten';
  end if;
end;
$$;

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

revoke all on function public.admin_list_artists(text) from public;
grant execute on function public.admin_list_artists(text) to anon, authenticated;
revoke all on function public.admin_set_artist_published(text, uuid, boolean) from public;
grant execute on function public.admin_set_artist_published(text, uuid, boolean) to anon, authenticated;
