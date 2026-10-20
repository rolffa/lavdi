-- Fjern bandmedlem. Tillater å tømme bandet helt (inkl. siste bandleder).
-- Trygt å kjøre på nytt. Krever is_band_member (inkl. admin «se som artist»).

create or replace function public.remove_band_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_band uuid;
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt.';
  end if;
  if p_member_id is null then
    raise exception 'Medlem mangler';
  end if;
  if not public.is_band_member() then
    raise exception 'Du er ikke med i et band.';
  end if;

  v_band := public.current_band_id();
  if v_band is null then
    raise exception 'Du er ikke med i et band.';
  end if;

  delete from public.band_members
  where id = p_member_id and band_id = v_band;

  if not found then
    raise exception 'Fant ikke medlemmet.';
  end if;
end;
$$;

-- Admin kan fjerne medlemmer uten å være i bandet.
create or replace function public.admin_remove_band_member(
  p_pin text,
  p_artist_id uuid,
  p_member_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_band uuid;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if p_artist_id is null or p_member_id is null then
    raise exception 'Artist eller medlem mangler';
  end if;

  select id into v_band
  from public.bands
  where artist_id = p_artist_id
  limit 1;

  if v_band is null then
    raise exception 'Fant ikke bandet';
  end if;

  delete from public.band_members
  where id = p_member_id and band_id = v_band;

  if not found then
    raise exception 'Fant ikke medlemmet.';
  end if;
end;
$$;

revoke all on function public.remove_band_member(uuid) from public;
grant execute on function public.remove_band_member(uuid) to authenticated;

revoke all on function public.admin_remove_band_member(text, uuid, uuid) from public;
grant execute on function public.admin_remove_band_member(text, uuid, uuid) to anon, authenticated;
