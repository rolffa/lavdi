-- Bandleder er en invitert person, ikke et auto-opprettet artist-sete.
-- Første invitasjon blir Bandleder. Trygt å kjøre på nytt.

create extension if not exists pgcrypto with schema extensions;

-- Fjern plassholder-bandledere (opprettet med bandnavn, uten innlogget bruker).
delete from public.band_members m
using public.bands b
where m.band_id = b.id
  and m.user_id is null
  and coalesce(m.er_leder, false)
  and (
    nullif(trim(m.navn), '') is null
    or lower(trim(m.navn)) = lower(trim(b.navn))
  );

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
  if v_band is not null then
    return v_band;
  end if;

  if not v_admin_view
     and exists (select 1 from public.band_members where user_id = auth.uid()) then
    raise exception 'Du er allerede med i et band.';
  end if;

  insert into public.bands (artist_id, navn, kontaktinfo, created_by)
  values (v_artist, v_name, coalesce(trim(p_kontakt), ''), auth.uid())
  returning id into v_band;

  -- Ingen auto-bandleder. Første invitasjon blir bandleder.
  return v_band;
end;
$$;

revoke all on function public.create_band(text, text) from public;
grant execute on function public.create_band(text, text) to authenticated;

-- Artist-eier (og admin-visning) skal styre bandet også uten medlemsrad.
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
    (select band_id from public.band_members where user_id = auth.uid() limit 1),
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
    )
    or exists (
      select 1
      from public.bands b
      join private.artist_logins l on l.artist_id = b.artist_id
      where l.auth_user_id = auth.uid()
    );
$$;

grant execute on function public.current_band_id() to authenticated;
grant execute on function public.is_band_member() to authenticated;
grant execute on function public.is_band_leader() to authenticated;

create or replace function public.invite_band_member(p_email text, p_rolle text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, private
as $$
declare
  v_band uuid;
  v_email text := lower(trim(p_email));
  v_role text := nullif(trim(p_rolle), '');
  v_token text;
  v_id uuid;
  v_has_member boolean;
begin
  if not public.is_band_member() then
    raise exception 'Du er ikke med i et band.';
  end if;
  if v_email is null or position('@' in v_email) = 0 then
    raise exception 'Oppgi en gyldig e-postadresse.';
  end if;
  if v_role is null then
    raise exception 'Oppgi en rolle.';
  end if;

  v_band := public.current_band_id();
  if v_band is null then
    raise exception 'Du er ikke med i et band.';
  end if;

  select exists (
    select 1 from public.band_members where band_id = v_band
  ) into v_has_member;

  -- Første person i bandet blir alltid bandleder.
  if not v_has_member then
    v_role := 'Bandleder';
  end if;

  v_token := encode(gen_random_bytes(16), 'hex');
  select id into v_id
  from public.band_invites
  where band_id = v_band and lower(email) = v_email and accepted_at is null;
  if v_id is null then
    insert into public.band_invites (band_id, email, rolle, token, invited_by)
    values (v_band, v_email, v_role, v_token, auth.uid())
    returning id into v_id;
  else
    update public.band_invites
    set rolle = v_role, token = v_token, invited_by = auth.uid()
    where id = v_id;
  end if;

  return jsonb_build_object(
    'id', v_id,
    'band_id', v_band,
    'epost', v_email,
    'rolle', v_role,
    'token', v_token
  );
end;
$$;

revoke all on function public.invite_band_member(text, text) from public;
grant execute on function public.invite_band_member(text, text) to authenticated;

create or replace function public.accept_band_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, private
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
    where user_id = auth.uid() and band_id <> v_invite.band_id
  ) then
    raise exception 'Kontoen er allerede med i et annet band.';
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
  on conflict (user_id) do update
    set rolle = coalesce(nullif(public.band_members.rolle, ''), excluded.rolle),
        er_leder = public.band_members.er_leder or excluded.er_leder
  returning id into v_member;

  update public.band_invites set accepted_at = now() where id = v_invite.id;
  return v_member;
end;
$$;

revoke all on function public.accept_band_invite(text) from public;
grant execute on function public.accept_band_invite(text) to authenticated;
