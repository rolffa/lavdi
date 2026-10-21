-- Bytt band: current_band_id må respektere private.user_active_band.
-- Regresjon: fix_band_crew_empty.sql fjernet dette steget.
-- Trygt å kjøre på nytt.

create or replace function public.current_band_id()
returns uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select coalesce(
    (
      select b.id
      from private.admin_artist_view v
      join public.bands b on b.artist_id = v.artist_id
      where v.auth_user_id = auth.uid()
      limit 1
    ),
    (
      select a.band_id
      from private.user_active_band a
      join public.band_members m
        on m.band_id = a.band_id and m.user_id = a.auth_user_id
      where a.auth_user_id = auth.uid()
      limit 1
    ),
    (
      select a.band_id
      from private.user_active_band a
      join public.bands b on b.id = a.band_id
      join private.artist_logins l on l.artist_id = b.artist_id
      where a.auth_user_id = auth.uid()
        and l.auth_user_id = auth.uid()
      limit 1
    ),
    (
      select band_id
      from public.band_members
      where user_id = auth.uid()
      order by created_at desc nulls last
      limit 1
    ),
    (
      select b.id
      from public.bands b
      join private.artist_logins l on l.artist_id = b.artist_id
      where l.auth_user_id = auth.uid()
      limit 1
    )
  );
$$;

revoke all on function public.current_band_id() from public;
grant execute on function public.current_band_id() to authenticated;
