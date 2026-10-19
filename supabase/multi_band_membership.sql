-- Tillat samme bruker i flere band. Trygt å kjøre på nytt.

-- 1) Unik per (band, bruker) i stedet for global unik user_id.
alter table public.band_members
  drop constraint if exists band_members_user_id_key;

drop index if exists public.band_members_user_id_key;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'band_members_band_user_key'
  ) then
    alter table public.band_members
      add constraint band_members_band_user_key unique (band_id, user_id);
  end if;
end $$;

-- Flere bandledere tillates (invitasjon som Bandleder).
drop index if exists public.band_members_one_leader_idx;

-- 2) Aktivt band for brukere med flere medlemskap.
create table if not exists private.user_active_band (
  auth_user_id uuid primary key references auth.users (id) on delete cascade,
  band_id uuid not null references public.bands (id) on delete cascade,
  updated_at timestamptz not null default now()
);

create or replace function public.set_active_band(p_band_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt.';
  end if;
  if p_band_id is null then
    raise exception 'Band mangler';
  end if;
  if not exists (
    select 1 from public.band_members
    where band_id = p_band_id and user_id = auth.uid()
  ) and not exists (
    select 1
    from public.bands b
    join private.artist_logins l on l.artist_id = b.artist_id
    where b.id = p_band_id and l.auth_user_id = auth.uid()
  ) and not exists (
    select 1 from private.admin_artist_view v
    join public.bands b on b.artist_id = v.artist_id
    where v.auth_user_id = auth.uid() and b.id = p_band_id
  ) then
    raise exception 'Du er ikke med i dette bandet.';
  end if;

  insert into private.user_active_band (auth_user_id, band_id, updated_at)
  values (auth.uid(), p_band_id, now())
  on conflict (auth_user_id) do update
    set band_id = excluded.band_id,
        updated_at = now();
end;
$$;

revoke all on function public.set_active_band(uuid) from public;
grant execute on function public.set_active_band(uuid) to authenticated;

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

grant execute on function public.current_band_id() to authenticated;

-- 3) Aksept: tillat flere band; sett aktivt band.
create or replace function public.accept_band_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_invite public.band_invites;
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_member uuid;
  v_leader boolean;
  v_has_member boolean;
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
    where user_id = auth.uid() and band_id = v_invite.band_id
  ) then
    update public.band_invites set accepted_at = now() where id = v_invite.id;
    perform public.set_active_band(v_invite.band_id);
    select id into v_member
    from public.band_members
    where user_id = auth.uid() and band_id = v_invite.band_id
    limit 1;
    return v_member;
  end if;

  select exists (
    select 1 from public.band_members where band_id = v_invite.band_id
  ) into v_has_member;

  v_leader :=
    (not v_has_member)
    or lower(btrim(v_invite.rolle)) in ('bandleder', 'leder');

  insert into public.band_members (band_id, user_id, rolle, er_leder)
  values (
    v_invite.band_id,
    auth.uid(),
    case when not v_has_member then 'Bandleder' else v_invite.rolle end,
    v_leader
  )
  on conflict (band_id, user_id) do update
    set rolle = coalesce(nullif(public.band_members.rolle, ''), excluded.rolle),
        er_leder = public.band_members.er_leder or excluded.er_leder
  returning id into v_member;

  update public.band_invites set accepted_at = now() where id = v_invite.id;
  perform public.set_active_band(v_invite.band_id);
  return v_member;
end;
$$;

revoke all on function public.accept_band_invite(text) from public;
grant execute on function public.accept_band_invite(text) to authenticated;

-- 4) create_band: ikke blokker fordi bruker allerede er med i et annet band.
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

  v_artist := public.current_artist_id();
  if v_artist is null then
    raise exception 'Ingen artist er koblet til kontoen.';
  end if;

  select id into v_band
  from public.bands
  where artist_id = v_artist
  limit 1;
  if v_band is not null then
    return v_band;
  end if;

  insert into public.bands (artist_id, navn, kontaktinfo, created_by)
  values (v_artist, v_name, coalesce(trim(p_kontakt), ''), auth.uid())
  returning id into v_band;

  return v_band;
end;
$$;

revoke all on function public.create_band(text, text) from public;
grant execute on function public.create_band(text, text) to authenticated;

-- 5) RLS: les for alle band brukeren er medlem i (ikke bare «aktivt»).
-- Security definer-hjelpere — aldri spør band_members/private.* direkte i policy.
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

drop policy if exists bands_member_read on public.bands;
drop policy if exists bands_read on public.bands;
create policy bands_read on public.bands
for select to authenticated
using (
  id = public.current_band_id()
  or id in (select private.user_band_ids())
  or artist_id in (select private.user_login_artist_ids())
  or artist_id in (select private.user_admin_view_artist_ids())
);
