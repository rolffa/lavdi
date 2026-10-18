-- Admin i Supabase Auth (profil / passord) i tillegg til private.admin_gate (PIN til RPC).
-- Kjør i SQL Editor etter account.sql. Trygt å kjøre på nytt.
--
-- Innlogging i appen: brukernavn «admin» + passord → Auth-session med auth_email.
-- Passordendring oppdaterer både pin_hash og auth.users.

alter table private.admin_gate
  add column if not exists username text not null default 'admin';

alter table private.admin_gate
  add column if not exists auth_email text not null default 'admin@lavdi.no';

alter table private.admin_gate
  add column if not exists auth_user_id uuid;

comment on column private.admin_gate.auth_email is
  'E-post i Supabase Auth for adminkontoen. Brukes til profil og passord.';
comment on column private.admin_gate.auth_user_id is
  'Kobling til auth.users.id for adminkontoen.';

update private.admin_gate
set auth_email = coalesce(nullif(btrim(auth_email), ''), 'admin@lavdi.no')
where id;

create or replace function public.admin_auth_email(p_username text default 'admin')
returns text
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_email text;
begin
  select nullif(btrim(auth_email), '')
  into v_email
  from private.admin_gate
  where lower(username) = lower(trim(coalesce(p_username, 'admin')));
  return coalesce(v_email, 'admin@lavdi.no');
end;
$$;

create or replace function private.admin_link_auth_user(
  p_email text,
  p_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, private, auth, extensions
as $$
declare
  v_email text := lower(trim(p_email));
  v_user_id uuid;
  v_encrypted text;
begin
  if v_email is null or position('@' in v_email) = 0 then
    raise exception 'Ugyldig admin-e-post.';
  end if;
  if length(trim(coalesce(p_password, ''))) < 4 then
    raise exception 'Passordet må være minst 4 tegn';
  end if;

  v_encrypted := crypt(trim(p_password), gen_salt('bf'));

  select id into v_user_id from auth.users where lower(email) = v_email;
  if v_user_id is null then
    v_user_id := gen_random_uuid();
    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) values (
      coalesce(
        (select instance_id from auth.users limit 1),
        '00000000-0000-0000-0000-000000000000'
      ),
      v_user_id,
      'authenticated',
      'authenticated',
      v_email,
      v_encrypted,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('role', 'admin', 'username', 'admin'),
      now(),
      now(),
      '',
      '',
      '',
      ''
    );

    insert into auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      provider_id,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      gen_random_uuid(),
      v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_email),
      'email',
      v_email,
      now(),
      now(),
      now()
    );
  else
    update auth.users
    set encrypted_password = v_encrypted,
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        updated_at = now(),
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
          || jsonb_build_object('role', 'admin', 'username', 'admin')
    where id = v_user_id;
  end if;

  return v_user_id;
end;
$$;

-- Verifiserer admin-passord og sørger for Auth-bruker + kobling.
create or replace function public.admin_ensure_auth(
  p_username text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, auth, extensions
as $$
declare
  v_email text;
  v_user_id uuid;
begin
  if not exists (
    select 1 from private.admin_gate
    where lower(username) = lower(trim(coalesce(p_username, '')))
      and crypt(coalesce(p_password, ''), pin_hash) = pin_hash
  ) then
    raise exception 'Feil brukernavn eller passord';
  end if;

  select auth_email into v_email
  from private.admin_gate
  where lower(username) = lower(trim(p_username));

  v_email := coalesce(nullif(btrim(v_email), ''), 'admin@lavdi.no');
  v_user_id := private.admin_link_auth_user(v_email, p_password);

  update private.admin_gate
  set auth_email = v_email,
      auth_user_id = v_user_id
  where lower(username) = lower(trim(p_username));

  return jsonb_build_object(
    'email', v_email,
    'user_id', v_user_id
  );
end;
$$;

create or replace function public.admin_change_password(
  p_username text,
  p_old text,
  p_new text
)
returns void
language plpgsql
security definer
set search_path = public, private, auth, extensions
as $$
declare
  v_email text;
  v_user_id uuid;
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
  where lower(username) = lower(trim(p_username))
  returning auth_email, auth_user_id into v_email, v_user_id;

  v_email := coalesce(nullif(btrim(v_email), ''), 'admin@lavdi.no');
  v_user_id := private.admin_link_auth_user(v_email, trim(p_new));

  update private.admin_gate
  set auth_email = v_email,
      auth_user_id = v_user_id
  where lower(username) = lower(trim(p_username));
end;
$$;

create or replace function public.is_portal_admin()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1 from private.admin_gate
    where auth_user_id = auth.uid()
       or lower(auth_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.admin_auth_email(text) from public;
revoke all on function public.admin_ensure_auth(text, text) from public;
revoke all on function public.admin_change_password(text, text, text) from public;
revoke all on function public.is_portal_admin() from public;
revoke all on function private.admin_link_auth_user(text, text) from public;

grant execute on function public.admin_auth_email(text) to anon, authenticated;
grant execute on function public.admin_ensure_auth(text, text) to anon, authenticated;
grant execute on function public.admin_change_password(text, text, text) to anon, authenticated;
grant execute on function public.is_portal_admin() to authenticated;
