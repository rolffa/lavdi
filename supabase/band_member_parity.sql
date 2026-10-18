-- Alle bandmedlemmer får samme rettigheter som bandleder i artistportalen:
-- invitere, oppdatere band/rider/scenekart, trekke invitasjoner, styre crew.
-- Trygt å kjøre på nytt.

create or replace function public.is_band_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.band_members
    where user_id = auth.uid()
  );
$$;

revoke all on function public.is_band_member() from public;
grant execute on function public.is_band_member() to authenticated;

create or replace function public.invite_band_member(p_email text, p_rolle text)
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

drop policy if exists bands_leader_update on public.bands;
drop policy if exists bands_member_update on public.bands;
create policy bands_member_update on public.bands
for update to authenticated
using (id = public.current_band_id() and public.is_band_member())
with check (id = public.current_band_id() and public.is_band_member());

drop policy if exists band_invites_leader_read on public.band_invites;
drop policy if exists band_invites_member_read on public.band_invites;
create policy band_invites_member_read on public.band_invites
for select to authenticated
using (band_id = public.current_band_id() and public.is_band_member());

drop policy if exists band_invites_leader_delete on public.band_invites;
drop policy if exists band_invites_member_delete on public.band_invites;
create policy band_invites_member_delete on public.band_invites
for delete to authenticated
using (band_id = public.current_band_id() and public.is_band_member() and accepted_at is null);

create or replace function public.set_crew_member_active(
  p_gig_id uuid,
  p_member_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt';
  end if;
  if not exists (
    select 1
    from public.band_members m
    join public.bands b on b.id = m.band_id
    join public.gigs g on g.artist_id = b.artist_id
    where g.id = p_gig_id
      and m.user_id = auth.uid()
  ) then
    raise exception 'Du er ikke med i et band.';
  end if;
  if not coalesce(p_active, false) and (
    select count(*) from public.gig_crew_travel
    where gig_id = p_gig_id and aktiv and id <> p_member_id
  ) = 0 then
    raise exception 'Minst én person må være med på konserten';
  end if;
  update public.gig_crew_travel
  set aktiv = coalesce(p_active, false),
      bestilt = case when coalesce(p_active, false) then bestilt else false end
  where id = p_member_id and gig_id = p_gig_id;
  if not found then
    raise exception 'Fant ikke medlemmet';
  end if;
  return public.my_crew_travel(p_gig_id);
end;
$$;

create or replace function public.can_receive_band_push()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_band_member();
$$;

create or replace function public.push_recipient_ids(p_artist_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select distinct m.user_id
  from public.band_members m
  join public.bands b on b.id = m.band_id
  where b.artist_id = p_artist_id
    and m.user_id is not null;
$$;

create or replace function public.save_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.can_receive_band_push() then
    raise exception 'Du er ikke med i et band.';
  end if;
  if p_endpoint is null or p_endpoint !~ '^https://' or btrim(p_p256dh) = '' or btrim(p_auth) = '' then
    raise exception 'Ugyldig push-abonnement.';
  end if;

  delete from public.user_push_subscriptions
  where endpoint = p_endpoint
    and user_id <> auth.uid();

  insert into public.user_push_subscriptions (user_id, endpoint, p256dh, auth)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id,
        p256dh = excluded.p256dh,
        auth = excluded.auth;
end;
$$;

-- Scenekart: alle bandmedlemmer kan laste opp/oppdatere/slette.
drop policy if exists stage_plots_leader_insert on storage.objects;
drop policy if exists stage_plots_member_insert on storage.objects;
create policy stage_plots_member_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_update on storage.objects;
drop policy if exists stage_plots_member_update on storage.objects;
create policy stage_plots_member_update on storage.objects
for update to authenticated
using (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
)
with check (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_delete on storage.objects;
drop policy if exists stage_plots_member_delete on storage.objects;
create policy stage_plots_member_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'stage-plots'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);
