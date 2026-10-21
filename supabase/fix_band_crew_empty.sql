-- Band/crew uten medlemsrad: artist-eier (og admin-visning) skal få oversikt.
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

create or replace function public.is_band_member()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select
    exists (select 1 from private.admin_artist_view where auth_user_id = auth.uid())
    or exists (select 1 from public.band_members where user_id = auth.uid())
    or exists (
      select 1
      from public.bands b
      join private.artist_logins l on l.artist_id = b.artist_id
      where l.auth_user_id = auth.uid()
    );
$$;

-- Oversikt for innlogget bruker. Fungerer også når bandet er tomt.
create or replace function public.my_band_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_band public.bands%rowtype;
  v_me public.band_members%rowtype;
  v_me_json jsonb;
  v_members jsonb;
  v_invites jsonb;
  v_band_id uuid;
  v_found boolean := false;
begin
  if auth.uid() is null then
    return null;
  end if;

  v_band_id := public.current_band_id();
  if v_band_id is null then
    return null;
  end if;

  select * into v_band from public.bands where id = v_band_id;
  if not found then
    return null;
  end if;

  select * into v_me
  from public.band_members
  where band_id = v_band_id and user_id = auth.uid()
  limit 1;

  if found then
    v_found := true;
  else
    select * into v_me
    from public.band_members
    where band_id = v_band_id and er_leder
    order by created_at nulls last
    limit 1;
    if found then
      v_found := true;
    end if;
  end if;

  if v_found then
    v_me_json := to_jsonb(v_me);
  else
    v_me_json := jsonb_build_object(
      'id', v_band.id,
      'band_id', v_band.id,
      'user_id', null,
      'navn', 'Admin',
      'rolle', 'Admin',
      'telefon', '',
      'mat', '',
      'tech_personlig', '',
      'er_leder', true,
      'created_at', v_band.created_at
    );
  end if;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.navn), '[]'::jsonb)
  into v_members
  from public.band_members m
  where m.band_id = v_band.id;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.email), '[]'::jsonb)
  into v_invites
  from public.band_invites i
  where i.band_id = v_band.id and i.accepted_at is null;

  return jsonb_build_object(
    'band', to_jsonb(v_band),
    'me', v_me_json,
    'members', v_members,
    'invites', v_invites
  );
end;
$$;

revoke all on function public.current_band_id() from public;
grant execute on function public.current_band_id() to authenticated;

revoke all on function public.is_band_member() from public;
grant execute on function public.is_band_member() to authenticated;

revoke all on function public.my_band_overview() from public;
grant execute on function public.my_band_overview() to authenticated;
