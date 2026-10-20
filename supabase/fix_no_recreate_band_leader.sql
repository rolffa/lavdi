-- Stopp auto-gjenoppretting av bandleder etter sletting.
-- Live create_band / attach_band_leader har satt inn Bandleder igjen
-- når artist-eier henter Band/crew. Trygt å kjøre på nytt.

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
    select 1
    from private.admin_artist_view
    where auth_user_id = auth.uid()
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

  -- Ingen auto-bandleder. Invitasjon setter rolle/er_leder.
  return v_band;
end;
$$;

-- Kun knytt eksisterende null-user leder-sete. Aldri lag ny Bandleder-rad.
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

  update public.band_members m
  set user_id = auth.uid()
  from public.bands b
  where m.band_id = b.id
    and m.er_leder
    and m.user_id is null
    and b.artist_id = (
      select artist_id
      from private.artist_logins
      where auth_user_id = auth.uid()
      limit 1
    );
end;
$$;

revoke all on function public.create_band(text, text) from public;
grant execute on function public.create_band(text, text) to authenticated;

revoke all on function public.attach_band_leader() from public;
grant execute on function public.attach_band_leader() to authenticated;
