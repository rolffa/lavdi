-- Fiks RLS uten å gi authenticated direkte tilgang til private.*-tabeller.
-- Policyer bruker security definer-hjelpere (unngår 42P17 og 42501).

create or replace function private.user_band_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select band_id
  from public.band_members
  where user_id = auth.uid();
$$;

create or replace function private.user_login_artist_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select artist_id
  from private.artist_logins
  where auth_user_id = auth.uid();
$$;

create or replace function private.user_admin_view_artist_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select artist_id
  from private.admin_artist_view
  where auth_user_id = auth.uid();
$$;

revoke all on function private.user_band_ids() from public;
revoke all on function private.user_login_artist_ids() from public;
revoke all on function private.user_admin_view_artist_ids() from public;
grant execute on function private.user_band_ids() to authenticated;
grant execute on function private.user_login_artist_ids() to authenticated;
grant execute on function private.user_admin_view_artist_ids() to authenticated;

drop policy if exists band_members_read on public.band_members;
create policy band_members_read on public.band_members
for select to authenticated
using (
  user_id = auth.uid()
  or band_id in (select private.user_band_ids())
  or exists (
    select 1 from public.bands b
    where b.id = band_members.band_id
      and (
        b.artist_id in (select private.user_login_artist_ids())
        or b.artist_id in (select private.user_admin_view_artist_ids())
      )
  )
);

drop policy if exists bands_read on public.bands;
create policy bands_read on public.bands
for select to authenticated
using (
  id = public.current_band_id()
  or id in (select private.user_band_ids())
  or artist_id in (select private.user_login_artist_ids())
  or artist_id in (select private.user_admin_view_artist_ids())
);
