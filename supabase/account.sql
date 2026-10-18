-- Konto: admin-passord, profilbilder, admin-invitasjon og engangskode.
-- Trygt å kjøre på nytt.

alter table private.admin_gate
  add column if not exists avatar_path text not null default '';

alter table public.band_members
  add column if not exists avatar_path text not null default '';

comment on column private.admin_gate.avatar_path is 'Sti i bucket avatars for admin profilbilde.';
comment on column public.band_members.avatar_path is 'Sti i bucket avatars for medlemmets profilbilde.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read on storage.objects
for select using (bucket_id = 'avatars');

drop policy if exists avatars_auth_write on storage.objects;
create policy avatars_auth_write on storage.objects
for insert to authenticated
with check (bucket_id = 'avatars');

drop policy if exists avatars_auth_update on storage.objects;
create policy avatars_auth_update on storage.objects
for update to authenticated
using (bucket_id = 'avatars')
with check (bucket_id = 'avatars');

drop policy if exists avatars_auth_delete on storage.objects;
create policy avatars_auth_delete on storage.objects
for delete to authenticated
using (bucket_id = 'avatars');

drop policy if exists avatars_anon_admin_write on storage.objects;
create policy avatars_anon_admin_write on storage.objects
for all to anon
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'admin')
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'admin');

create or replace function public.admin_change_password(
  p_username text,
  p_old text,
  p_new text
)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if length(trim(coalesce(p_new, ''))) < 4 then
    raise exception 'Nytt passord må være minst 4 tegn';
  end if;
  if not exists (
    select 1 from private.admin_gate
    where lower(username) = lower(trim(coalesce(p_username, '')))
      and crypt(coalesce(p_old, ''), pin_hash) = pin_hash
  ) then
    raise exception 'Feil brukernavn eller passord';
  end if;
  update private.admin_gate
  set pin_hash = crypt(trim(p_new), gen_salt('bf'))
  where lower(username) = lower(trim(p_username));
end;
$$;

create or replace function public.admin_avatar_url(p_pin text)
returns text
language plpgsql
stable
security definer
set search_path = public, private, extensions
as $$
declare
  path text;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  select nullif(btrim(avatar_path), '') into path from private.admin_gate where id;
  return coalesce(path, '');
end;
$$;

create or replace function public.admin_set_avatar(p_pin text, p_path text)
returns text
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  update private.admin_gate
  set avatar_path = trim(coalesce(p_path, ''))
  where id;
  return trim(coalesce(p_path, ''));
end;
$$;

create or replace function public.my_avatar_path()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  path text;
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt';
  end if;
  select nullif(btrim(avatar_path), '') into path
  from public.band_members
  where user_id = auth.uid();
  return coalesce(path, '');
end;
$$;

create or replace function public.set_my_avatar(p_path text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt';
  end if;
  update public.band_members
  set avatar_path = trim(coalesce(p_path, ''))
  where user_id = auth.uid();
  if not found then
    raise exception 'Du er ikke med i et band ennå';
  end if;
  return trim(coalesce(p_path, ''));
end;
$$;

create or replace function public.admin_list_band_accounts(p_pin text, p_artist_id uuid)
returns jsonb
language plpgsql
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
        'id', m.id,
        'band_id', m.band_id,
        'navn', m.navn,
        'rolle', m.rolle,
        'epost', coalesce(u.email, ''),
        'er_leder', m.er_leder,
        'avatar_path', coalesce(m.avatar_path, '')
      )
      order by m.er_leder desc, m.navn
    )
    from public.bands b
    join public.band_members m on m.band_id = b.id
    left join auth.users u on u.id = m.user_id
    where b.artist_id = p_artist_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_invite_band_member(
  p_pin text,
  p_artist_id uuid,
  p_email text,
  p_rolle text,
  p_er_leder boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_band uuid;
  v_email text := lower(trim(p_email));
  v_role text := nullif(trim(p_rolle), '');
  v_token text;
  v_id uuid;
  artist_navn text;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if v_email is null or position('@' in v_email) = 0 then
    raise exception 'Oppgi en gyldig e-postadresse.';
  end if;
  if v_role is null then
    raise exception 'Oppgi en rolle.';
  end if;
  if coalesce(p_er_leder, false) then
    v_role := 'Bandleder';
  end if;

  select id into v_band from public.bands where artist_id = p_artist_id limit 1;
  if v_band is null then
    select navn into artist_navn from public.artists where id = p_artist_id;
    if artist_navn is null then
      raise exception 'Fant ikke artisten';
    end if;
    insert into public.bands (artist_id, navn, kontaktinfo)
    values (p_artist_id, artist_navn, '')
    returning id into v_band;
  end if;

  v_token := encode(gen_random_bytes(16), 'hex');
  select id into v_id
  from public.band_invites
  where band_id = v_band and lower(email) = v_email and accepted_at is null;
  if v_id is null then
    insert into public.band_invites (band_id, email, rolle, token)
    values (v_band, v_email, v_role, v_token)
    returning id into v_id;
  else
    update public.band_invites
    set rolle = v_role, token = v_token
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

-- Sett er_leder når invitasjonsrollen er bandleder.
create or replace function public.accept_band_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.band_invites;
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_member uuid;
  v_leader boolean;
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
  v_leader := lower(btrim(v_invite.rolle)) in ('bandleder', 'leder');
  insert into public.band_members (band_id, user_id, rolle, er_leder)
  values (v_invite.band_id, auth.uid(), v_invite.rolle, v_leader)
  on conflict (user_id) do update
    set rolle = coalesce(nullif(public.band_members.rolle, ''), excluded.rolle),
        er_leder = public.band_members.er_leder or excluded.er_leder
  returning id into v_member;
  update public.band_invites set accepted_at = now() where id = v_invite.id;
  return v_member;
end;
$$;

revoke all on function public.admin_change_password(text, text, text) from public;
grant execute on function public.admin_change_password(text, text, text) to anon, authenticated;
revoke all on function public.admin_avatar_url(text) from public;
grant execute on function public.admin_avatar_url(text) to anon, authenticated;
revoke all on function public.admin_set_avatar(text, text) from public;
grant execute on function public.admin_set_avatar(text, text) to anon, authenticated;
revoke all on function public.my_avatar_path() from public;
grant execute on function public.my_avatar_path() to authenticated;
revoke all on function public.set_my_avatar(text) from public;
grant execute on function public.set_my_avatar(text) to authenticated;
revoke all on function public.admin_list_band_accounts(text, uuid) from public;
grant execute on function public.admin_list_band_accounts(text, uuid) to anon, authenticated;
revoke all on function public.admin_invite_band_member(text, uuid, text, text, boolean) from public;
grant execute on function public.admin_invite_band_member(text, uuid, text, text, boolean) to anon, authenticated;
