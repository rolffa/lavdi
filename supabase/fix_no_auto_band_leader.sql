-- Ingen auto-bandleder: rolle/er_leder følger kun invitasjonen.
-- Band kan eksistere uten bandleder. Trygt å kjøre på nytt.

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
  v_role text;
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

  -- Rydd tomme placeholder-seter uten bruker.
  delete from public.band_members
  where band_id = v_invite.band_id and user_id is null;

  v_role := coalesce(nullif(trim(v_invite.rolle), ''), 'Medlem');
  v_leader := lower(btrim(v_role)) in ('bandleder', 'leder');

  insert into public.band_members (band_id, user_id, rolle, er_leder)
  values (v_invite.band_id, auth.uid(), v_role, v_leader)
  on conflict (band_id, user_id) do update
    set rolle = coalesce(nullif(public.band_members.rolle, ''), excluded.rolle),
        er_leder = public.band_members.er_leder or excluded.er_leder
  returning id into v_member;

  update public.band_invites set accepted_at = now() where id = v_invite.id;
  perform public.set_active_band(v_invite.band_id);
  return v_member;
end;
$$;

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
  -- Ikke overstyr rolle til Bandleder for første medlem.
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

revoke all on function public.accept_band_invite(text) from public;
grant execute on function public.accept_band_invite(text) to authenticated;
revoke all on function public.invite_band_member(text, text) from public;
grant execute on function public.invite_band_member(text, text) to authenticated;
