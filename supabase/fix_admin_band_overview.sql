-- Admin Band/crew: tillat oversikt uten medlemsrad.
-- Tidligere returnerte admin_band_overview null når bandet manglet leder/medlem
-- → «Bandet ble ikke opprettet.» i admin «se som artist».
-- Trygt å kjøre på nytt.

create or replace function public.admin_band_overview(
  p_pin text,
  p_artist_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_band public.bands%rowtype;
  v_me public.band_members%rowtype;
  v_me_json jsonb;
  v_members jsonb;
  v_invites jsonb;
  v_found_member boolean := false;
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  if p_artist_id is null then
    raise exception 'Artist mangler';
  end if;

  select * into v_band
  from public.bands
  where artist_id = p_artist_id
  limit 1;

  if not found then
    return null;
  end if;

  select * into v_me
  from public.band_members
  where band_id = v_band.id and er_leder
  order by created_at nulls last
  limit 1;

  if found then
    v_found_member := true;
  else
    select * into v_me
    from public.band_members
    where band_id = v_band.id
    order by created_at nulls last
    limit 1;
    if found then
      v_found_member := true;
    end if;
  end if;

  if v_found_member then
    v_me_json := to_jsonb(v_me);
  else
    -- Syntetisk admin-sete slik at portalen kan åpnes før første invitasjon.
    v_me_json := jsonb_build_object(
      'id', v_band.id,
      'band_id', v_band.id,
      'user_id', null,
      'navn', 'Admin',
      'rolle', 'Admin',
      'telefon', '',
      'mat', '',
      'tech_personlig', '',
      'er_leder', true,
      'created_at', v_band.created_at
    );
  end if;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.navn), '[]'::jsonb)
  into v_members
  from public.band_members m
  where m.band_id = v_band.id;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.email), '[]'::jsonb)
  into v_invites
  from public.band_invites i
  where i.band_id = v_band.id and i.accepted_at is null;

  return jsonb_build_object(
    'band', to_jsonb(v_band),
    'me', v_me_json,
    'members', v_members,
    'invites', v_invites
  );
end;
$$;

revoke all on function public.admin_band_overview(text, uuid) from public;
grant execute on function public.admin_band_overview(text, uuid) to anon, authenticated;
