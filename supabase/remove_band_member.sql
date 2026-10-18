-- Fjern bandmedlem. Trygt å kjøre på nytt.
-- Krever is_band_leader / is_band_member (inkl. admin «se som artist»).

create or replace function public.remove_band_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_band uuid;
  v_is_leader boolean;
  v_leader_count int;
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

  -- Alle i bandet kan fjerne (samme terskel som invitasjon),
  -- men siste bandleder kan ikke slettes.
  select er_leder into v_is_leader
  from public.band_members
  where id = p_member_id and band_id = v_band;

  if not found then
    raise exception 'Fant ikke medlemmet.';
  end if;

  if coalesce(v_is_leader, false) then
    select count(*)::int into v_leader_count
    from public.band_members
    where band_id = v_band and er_leder;
    if v_leader_count <= 1 then
      raise exception 'Kan ikke fjerne den eneste bandlederen.';
    end if;
  end if;

  delete from public.band_members
  where id = p_member_id and band_id = v_band;
end;
$$;

revoke all on function public.remove_band_member(uuid) from public;
grant execute on function public.remove_band_member(uuid) to authenticated;
