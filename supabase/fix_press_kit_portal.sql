-- Portal: lese/redigere pressepakke også for upubliserte artister,
-- og når admin «ser som artist». Trygt å kjøre på nytt.

-- Medlemmer (og publiserte) kan lese artist-raden i portalen.
drop policy if exists artists_public_read on public.artists;
create policy artists_public_read on public.artists
for select to anon, authenticated
using (
  publisert
  or exists (
    select 1
    from public.bands b
    join public.band_members m on m.band_id = b.id
    where b.artist_id = artists.id
      and m.user_id = auth.uid()
  )
);

create or replace function public.admin_upsert_band_press_kit(
  p_pin text,
  p_artist_id uuid,
  p_bio text default null,
  p_press_photo_1 text default null,
  p_press_photo_2 text default null,
  p_press_photo_3 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_band uuid;
  v_row public.band_press_kit%rowtype;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if p_artist_id is null then
    raise exception 'Artist mangler';
  end if;

  select id into v_band
  from public.bands
  where artist_id = p_artist_id
  limit 1;
  if v_band is null then
    raise exception 'Opprett bandet før du lager pressepakke.';
  end if;

  insert into public.band_press_kit (band_id, bio, press_photo_1, press_photo_2, press_photo_3)
  values (
    v_band,
    coalesce(nullif(trim(p_bio), ''), ''),
    coalesce(nullif(trim(p_press_photo_1), ''), ''),
    coalesce(nullif(trim(p_press_photo_2), ''), ''),
    coalesce(nullif(trim(p_press_photo_3), ''), '')
  )
  on conflict (band_id) do update
    set bio = case
          when p_bio is null then public.band_press_kit.bio
          else coalesce(nullif(trim(p_bio), ''), '')
        end,
        press_photo_1 = case
          when p_press_photo_1 is null then public.band_press_kit.press_photo_1
          else coalesce(nullif(trim(p_press_photo_1), ''), public.band_press_kit.press_photo_1)
        end,
        press_photo_2 = case
          when p_press_photo_2 is null then public.band_press_kit.press_photo_2
          else coalesce(nullif(trim(p_press_photo_2), ''), public.band_press_kit.press_photo_2)
        end,
        press_photo_3 = case
          when p_press_photo_3 is null then public.band_press_kit.press_photo_3
          else coalesce(nullif(trim(p_press_photo_3), ''), public.band_press_kit.press_photo_3)
        end
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

revoke all on function public.admin_upsert_band_press_kit(
  text, uuid, text, text, text, text
) from public;
grant execute on function public.admin_upsert_band_press_kit(
  text, uuid, text, text, text, text
) to anon, authenticated;
