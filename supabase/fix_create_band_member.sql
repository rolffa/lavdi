-- Robust fiks: create_band + medlemsrad uten å kreve ON CONFLICT (band_id, user_id).
-- Forrige kjøring kunne rulleres tilbake hvis unik-constraint manglet.
-- Trygt å kjøre på nytt.

-- 1) Tillat samme bruker i flere band.
alter table public.band_members
  drop constraint if exists band_members_user_id_key;

drop index if exists public.band_members_user_id_key;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'band_members_band_user_key'
  ) then
    alter table public.band_members
      add constraint band_members_band_user_key unique (band_id, user_id);
  end if;
exception
  when unique_violation then
    -- Duplikater finnes allerede; fortsett uten ny constraint.
    raise notice 'Kunne ikke legge til band_members_band_user_key (duplikater).';
end $$;

drop index if exists public.band_members_one_leader_idx;

-- 2) create_band: alltid medlemsrad for innlogget artist (ikke admin-view).
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
  v_member_name text;
  v_admin_view boolean := false;
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

  v_admin_view := exists (
    select 1 from private.admin_artist_view where auth_user_id = auth.uid()
  );

  select id into v_band
  from public.bands
  where artist_id = v_artist
  limit 1;

  if v_admin_view then
    if v_band is null then
      insert into public.bands (artist_id, navn, kontaktinfo, created_by)
      values (v_artist, v_name, coalesce(trim(p_kontakt), ''), auth.uid())
      returning id into v_band;
    end if;
    return v_band;
  end if;

  select coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(split_part(coalesce(u.email, ''), '@', 1)), ''),
    v_name
  )
  into v_member_name
  from auth.users u
  where u.id = auth.uid();

  if v_band is null then
    insert into public.bands (artist_id, navn, kontaktinfo, created_by)
    values (v_artist, v_name, coalesce(trim(p_kontakt), ''), auth.uid())
    returning id into v_band;
  end if;

  if not exists (
    select 1 from public.band_members
    where band_id = v_band and user_id = auth.uid()
  ) then
    insert into public.band_members (band_id, user_id, navn, rolle, er_leder)
    values (v_band, auth.uid(), coalesce(v_member_name, v_name), 'Bandleder', true);
  else
    update public.band_members
    set er_leder = true,
        rolle = case
          when nullif(trim(rolle), '') is null then 'Bandleder'
          else rolle
        end,
        navn = case
          when nullif(trim(navn), '') is null then coalesce(v_member_name, v_name)
          else navn
        end
    where band_id = v_band and user_id = auth.uid();
  end if;

  begin
    perform public.set_active_band(v_band);
  exception
    when others then
      -- Aktivt band er nice-to-have; medlemskap er det kritiske.
      null;
  end;

  return v_band;
end;
$$;

revoke all on function public.create_band(text, text) from public;
grant execute on function public.create_band(text, text) to authenticated;

-- 3) Reparér band uten medlemsrad.
-- a) Artist-innlogging
insert into public.band_members (band_id, user_id, navn, rolle, er_leder)
select
  b.id,
  l.auth_user_id,
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(split_part(coalesce(u.email, ''), '@', 1)), ''),
    b.navn
  ),
  'Bandleder',
  true
from public.bands b
join private.artist_logins l on l.artist_id = b.artist_id
join auth.users u on u.id = l.auth_user_id
where not exists (
  select 1
  from public.band_members m
  where m.band_id = b.id and m.user_id = l.auth_user_id
);

-- b) Opprettet av bruker uten artist_logins (f.eks. EiGA / R & GM)
insert into public.band_members (band_id, user_id, navn, rolle, er_leder)
select
  b.id,
  b.created_by,
  b.navn,
  'Bandleder',
  true
from public.bands b
where b.created_by is not null
  and not exists (
    select 1 from public.band_members m
    where m.band_id = b.id and m.user_id = b.created_by
  );

-- 4) attach_band_leader: opprett medlemsrad hvis den mangler.
create or replace function public.attach_band_leader()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_artist uuid;
  v_band uuid;
  v_name text;
begin
  if auth.uid() is null then
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

  select artist_id into v_artist
  from private.artist_logins
  where auth_user_id = auth.uid()
  limit 1;
  if v_artist is null then
    return;
  end if;

  select id, navn into v_band, v_name
  from public.bands
  where artist_id = v_artist
  limit 1;
  if v_band is null then
    return;
  end if;

  if exists (
    select 1 from public.band_members
    where band_id = v_band and user_id = auth.uid()
  ) then
    return;
  end if;

  insert into public.band_members (band_id, user_id, navn, rolle, er_leder)
  values (v_band, auth.uid(), coalesce(v_name, 'Bandleder'), 'Bandleder', true);
end;
$$;

revoke all on function public.attach_band_leader() from public;
grant execute on function public.attach_band_leader() to authenticated;

-- 5) Bekreftelse
select
  b.navn,
  (select count(*) from public.band_members m where m.band_id = b.id) as members,
  exists (
    select 1 from private.artist_logins l
    join public.band_members m on m.band_id = b.id and m.user_id = l.auth_user_id
    where l.artist_id = b.artist_id
  ) as owner_linked
from public.bands b
order by b.navn;
