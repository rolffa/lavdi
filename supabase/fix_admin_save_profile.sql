-- Admin kan lagre bandmedlemsprofil når «se som artist».
-- Artist-invitasjon kan ikke bruke rollen Bandleder (kun admin).
-- Trygt å kjøre på nytt.

create or replace function public.admin_save_band_member_profile(
  p_pin text,
  p_artist_id uuid,
  p_member_id uuid,
  p_navn text,
  p_rolle text,
  p_telefon text,
  p_mat text,
  p_tech_personlig text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_band uuid;
  v_row public.band_members%rowtype;
  v_navn text := nullif(trim(p_navn), '');
  v_rolle text := nullif(trim(p_rolle), '');
  v_telefon text := nullif(trim(p_telefon), '');
  v_mat text := nullif(trim(p_mat), '');
  v_tech text := nullif(trim(p_tech_personlig), '');
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if v_navn is null or v_rolle is null or v_telefon is null
     or v_mat is null or v_tech is null then
    raise exception 'Navn, rolle, telefon, mat og tekniske behov må fylles ut.';
  end if;

  select id into v_band
  from public.bands
  where artist_id = p_artist_id
  limit 1;
  if v_band is null then
    raise exception 'Fant ikke bandet.';
  end if;

  update public.band_members
  set
    navn = v_navn,
    rolle = v_rolle,
    telefon = v_telefon,
    mat = v_mat,
    tech_personlig = v_tech,
    er_leder = lower(btrim(v_rolle)) in ('bandleder', 'leder')
      or er_leder
  where id = p_member_id
    and band_id = v_band
  returning * into v_row;

  if not found then
    raise exception 'Fant ikke medlemmet.';
  end if;

  return to_jsonb(v_row) || jsonb_build_object(
    'epost', coalesce(
      (select lower(btrim(u.email))
       from auth.users u
       where u.id = v_row.user_id),
      ''
    )
  );
end;
$$;

revoke all on function public.admin_save_band_member_profile(
  text, uuid, uuid, text, text, text, text, text
) from public;
grant execute on function public.admin_save_band_member_profile(
  text, uuid, uuid, text, text, text, text, text
) to anon, authenticated;

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
  if lower(btrim(v_role)) in ('bandleder', 'leder') then
    raise exception 'Bandleder inviteres kun fra adminportalen.';
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
