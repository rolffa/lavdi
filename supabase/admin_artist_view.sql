-- Admin kan åpne artistportal uten å logge inn som bandmedlem.
-- Trygt å kjøre på nytt. Krever admin_check_pin.

create schema if not exists private;

create table if not exists private.admin_artist_view (
  auth_user_id uuid primary key,
  artist_id uuid not null references public.artists (id) on delete cascade,
  opened_at timestamptz not null default now()
);

comment on table private.admin_artist_view is
  'Aktiv «se som artist»-økt for innlogget admin (auth.users).';

create or replace function public.admin_open_artist_view(
  p_pin text,
  p_artist_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_name text;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if auth.uid() is null then
    raise exception 'Admin må være innlogget med Auth for å åpne artistportal.';
  end if;
  if p_artist_id is null then
    raise exception 'Artist mangler';
  end if;

  select navn into v_name from public.artists where id = p_artist_id;
  if v_name is null then
    raise exception 'Fant ikke artisten';
  end if;

  insert into private.admin_artist_view (auth_user_id, artist_id, opened_at)
  values (auth.uid(), p_artist_id, now())
  on conflict (auth_user_id) do update
    set artist_id = excluded.artist_id,
        opened_at = now();

  return jsonb_build_object(
    'artist_id', p_artist_id,
    'navn', v_name,
    'epost', auth.jwt() ->> 'email',
    'as_admin', true
  );
end;
$$;

create or replace function public.admin_close_artist_view(p_pin text)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if auth.uid() is null then
    return;
  end if;
  delete from private.admin_artist_view where auth_user_id = auth.uid();
end;
$$;

create or replace function public.current_artist_id()
returns uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select coalesce(
    (select artist_id from private.admin_artist_view where auth_user_id = auth.uid()),
    (select artist_id from private.artist_logins where auth_user_id = auth.uid()),
    (
      select b.artist_id
      from public.band_members m
      join public.bands b on b.id = m.band_id
      where m.user_id = auth.uid()
      limit 1
    )
  );
$$;

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
    (select band_id from public.band_members where user_id = auth.uid() limit 1)
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
    or exists (select 1 from public.band_members where user_id = auth.uid());
$$;

create or replace function public.is_band_leader()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select
    exists (select 1 from private.admin_artist_view where auth_user_id = auth.uid())
    or exists (
      select 1 from public.band_members
      where user_id = auth.uid() and er_leder
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
    'epost', auth.jwt() ->> 'email',
    'as_admin', exists (
      select 1 from private.admin_artist_view v
      where v.auth_user_id = auth.uid() and v.artist_id = a.id
    )
  )
  from public.artists a
  where a.id = public.current_artist_id();
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
  -- Ikke knytt admin-brukeren til bandet under «se som artist».
  if exists (select 1 from private.admin_artist_view where auth_user_id = auth.uid()) then
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

create or replace function public.admin_band_overview(
  p_pin text,
  p_artist_id uuid
)
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
  v_found_member boolean := false;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if p_artist_id is null then
    raise exception 'Artist mangler';
  end if;

  select * into v_band
  from public.bands
  where artist_id = p_artist_id
  limit 1;

  if not found then
    return null;
  end if;

  select * into v_me
  from public.band_members
  where band_id = v_band.id and er_leder
  order by created_at nulls last
  limit 1;

  if found then
    v_found_member := true;
  else
    select * into v_me
    from public.band_members
    where band_id = v_band.id
    order by created_at nulls last
    limit 1;
    if found then
      v_found_member := true;
    end if;
  end if;

  if v_found_member then
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

revoke all on function public.admin_open_artist_view(text, uuid) from public;
grant execute on function public.admin_open_artist_view(text, uuid) to authenticated;

revoke all on function public.admin_close_artist_view(text) from public;
grant execute on function public.admin_close_artist_view(text) to authenticated;

revoke all on function public.admin_band_overview(text, uuid) from public;
grant execute on function public.admin_band_overview(text, uuid) to anon, authenticated;

grant execute on function public.current_artist_id() to authenticated;
grant execute on function public.artist_me() to authenticated;
grant execute on function public.current_band_id() to authenticated;
grant execute on function public.is_band_member() to authenticated;
grant execute on function public.is_band_leader() to authenticated;
grant execute on function public.attach_band_leader() to authenticated;

-- Merk: create_band for admin-visning ligger i supabase/admin_create_band_fix.sql
-- og bruker current_artist_id() + oppretter bandleder uten å knytte admin-Auth.
