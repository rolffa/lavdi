-- Invite-token trenger pgcrypto (gen_random_bytes). Trygt å kjøre på nytt.

create extension if not exists pgcrypto with schema extensions;

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

-- Samme token-generering for admin-invitasjon.
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
set search_path = public, extensions, private
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

revoke all on function public.admin_invite_band_member(text, uuid, text, text, boolean) from public;
grant execute on function public.admin_invite_band_member(text, uuid, text, text, boolean) to anon, authenticated;
