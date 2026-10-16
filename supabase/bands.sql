-- Band, medlemmer og invitasjon uten manuelle ID-koder.
-- Trygt å kjøre på nytt etter schema.sql.
--
-- Bandlederen er brukeren som allerede er koblet i private.artist_logins.
-- Medlemmer aktiveres via lenken /min-side/invitasjon/<token>.
-- I Supabase Auth: tillat magisk lenke for nye brukere, og legg
-- https://<nettsted>/min-side/invitasjon/** inn som redirect-URL.

create table if not exists public.bands (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid unique references public.artists (id) on delete cascade,
  navn text not null,
  kontaktinfo text not null default '',
  tech_felles text not null default '',
  hospitality_felles text not null default '',
  input_liste text not null default '',
  monitor text not null default '',
  scenerigg text not null default '',
  pa_krav text not null default '',
  stage_plot_path text,
  stage_plot_name text,
  stage_plot_type text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.bands is 'Ett band per artist. tech_felles og hospitality_felles er felles rider, ikke kjøreplan.';

create table if not exists public.band_members (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  user_id uuid unique references auth.users (id) on delete cascade,
  navn text not null default '',
  rolle text not null default '',
  telefon text not null default '',
  mat text not null default '',
  tech_personlig text not null default '',
  er_leder boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists band_members_one_leader_idx
  on public.band_members (band_id)
  where er_leder;

comment on table public.band_members is 'Medlem eller crew. user_id peker på auth.users når kontoen er aktivert.';
comment on column public.band_members.rolle is 'Instrument eller rolle, for eksempel musiker, lydtekniker eller turnéleder.';
comment on column public.band_members.mat is 'Dietter, allergier og spesielle ønsker.';
comment on column public.band_members.tech_personlig is 'IEM, trådløse frekvenser, mikrofon, DI og strøm.';

create table if not exists public.band_invites (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  email text not null,
  rolle text not null,
  token text not null unique,
  invited_by uuid references auth.users (id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists band_invites_open_email_idx
  on public.band_invites (band_id, lower(email))
  where accepted_at is null;

comment on table public.band_invites is 'E-postinvitasjon. Tokenet i lenken aktiverer kontoen uten manuell ID.';

create or replace function public.current_artist_id()
returns uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select coalesce(
    (select artist_id from private.artist_logins where auth_user_id = auth.uid()),
    (
      select b.artist_id
      from public.band_members m
      join public.bands b on b.id = m.band_id
      where m.user_id = auth.uid()
    )
  );
$$;

create or replace function public.artist_me()
returns jsonb
language sql
stable
security definer
set search_path = public, private
as $$
  select jsonb_build_object(
    'artist_id', a.id,
    'navn', a.navn,
    'epost', auth.jwt() ->> 'email'
  )
  from public.artists a
  where a.id = public.current_artist_id();
$$;

create or replace function public.current_band_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select band_id from public.band_members where user_id = auth.uid();
$$;

create or replace function public.is_band_leader()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.band_members
    where user_id = auth.uid() and er_leder
  );
$$;

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
  if exists (select 1 from public.band_members where user_id = auth.uid()) then
    return;
  end if;
  update public.band_members m
  set user_id = auth.uid()
  from public.bands b
  where m.band_id = b.id
    and m.er_leder
    and m.user_id is null
    and b.artist_id = (
      select artist_id from private.artist_logins where auth_user_id = auth.uid()
    );
end;
$$;

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
begin
  if auth.uid() is null then
    raise exception 'Logg inn på nytt.';
  end if;
  if v_name is null then
    raise exception 'Bandet trenger et navn.';
  end if;
  if exists (select 1 from public.band_members where user_id = auth.uid()) then
    raise exception 'Du er allerede med i et band.';
  end if;
  v_artist := (
    select artist_id from private.artist_logins where auth_user_id = auth.uid()
  );
  if v_artist is not null and exists (select 1 from public.bands where artist_id = v_artist) then
    raise exception 'Bandet finnes allerede.';
  end if;
  insert into public.bands (artist_id, navn, kontaktinfo, created_by)
  values (v_artist, v_name, coalesce(trim(p_kontakt), ''), auth.uid())
  returning id into v_band;
  insert into public.band_members (band_id, user_id, navn, rolle, er_leder)
  values (v_band, auth.uid(), v_name, 'Bandleder', true);
  return v_band;
end;
$$;

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
  if not public.is_band_leader() then
    raise exception 'Bare bandlederen kan invitere.';
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

create or replace function public.invite_preview(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'band_navn', b.navn,
    'epost', i.email,
    'rolle', i.rolle,
    'brukt', i.accepted_at is not null
  )
  from public.band_invites i
  join public.bands b on b.id = i.band_id
  where i.token = p_token;
$$;

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
  insert into public.band_members (band_id, user_id, rolle)
  values (v_invite.band_id, auth.uid(), v_invite.rolle)
  on conflict (user_id) do update
    set rolle = coalesce(nullif(public.band_members.rolle, ''), excluded.rolle)
  returning id into v_member;
  update public.band_invites set accepted_at = now() where id = v_invite.id;
  return v_member;
end;
$$;

create or replace function public.riders_for_token(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', b.id,
    'artist_id', b.artist_id,
    'navn', b.navn,
    'kontaktinfo', b.kontaktinfo,
    'tech_felles', b.tech_felles,
    'hospitality_felles', b.hospitality_felles,
    'input_liste', b.input_liste,
    'monitor', b.monitor,
    'scenerigg', b.scenerigg,
    'pa_krav', b.pa_krav,
    'stage_plot_name', b.stage_plot_name,
    'stage_plot_type', b.stage_plot_type,
    'medlemmer', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'band_id', m.band_id,
          'navn', m.navn,
          'rolle', m.rolle,
          'telefon', m.telefon,
          'mat', m.mat,
          'tech_personlig', m.tech_personlig,
          'er_leder', m.er_leder
        )
        order by m.er_leder desc, m.navn
      )
      from public.band_members m
      where m.band_id = b.id
    ), '[]'::jsonb)
  )
  from public.gigs g
  join public.bands b on b.artist_id = g.artist_id
  where g.booking_token = p_token;
$$;

revoke all on function public.current_artist_id() from public, anon;
revoke all on function public.artist_me() from public, anon;
revoke all on function public.current_band_id() from public;
revoke all on function public.is_band_leader() from public;
revoke all on function public.attach_band_leader() from public;
revoke all on function public.create_band(text, text) from public;
revoke all on function public.invite_band_member(text, text) from public;
revoke all on function public.invite_preview(text) from public;
revoke all on function public.accept_band_invite(text) from public;
revoke all on function public.riders_for_token(text) from public;

grant execute on function public.current_artist_id() to authenticated;
grant execute on function public.artist_me() to authenticated;
grant execute on function public.current_band_id() to authenticated;
grant execute on function public.is_band_leader() to authenticated;
grant execute on function public.attach_band_leader() to authenticated;
grant execute on function public.create_band(text, text) to authenticated;
grant execute on function public.invite_band_member(text, text) to authenticated;
grant execute on function public.invite_preview(text) to anon, authenticated;
grant execute on function public.accept_band_invite(text) to authenticated;
grant execute on function public.riders_for_token(text) to anon, authenticated;

alter table public.bands enable row level security;
alter table public.band_members enable row level security;
alter table public.band_invites enable row level security;

drop policy if exists bands_member_read on public.bands;
create policy bands_member_read on public.bands
for select to authenticated
using (id = public.current_band_id());

drop policy if exists bands_leader_update on public.bands;
create policy bands_leader_update on public.bands
for update to authenticated
using (id = public.current_band_id() and public.is_band_leader())
with check (id = public.current_band_id() and public.is_band_leader());

drop policy if exists band_members_read on public.band_members;
create policy band_members_read on public.band_members
for select to authenticated
using (band_id = public.current_band_id());

drop policy if exists band_members_self_update on public.band_members;
create policy band_members_self_update on public.band_members
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and band_id = public.current_band_id());

drop policy if exists band_invites_leader_read on public.band_invites;
create policy band_invites_leader_read on public.band_invites
for select to authenticated
using (band_id = public.current_band_id() and public.is_band_leader());

drop policy if exists band_invites_leader_delete on public.band_invites;
create policy band_invites_leader_delete on public.band_invites
for delete to authenticated
using (band_id = public.current_band_id() and public.is_band_leader() and accepted_at is null);

grant select, update on table public.bands to authenticated;
grant select on table public.band_members to authenticated;
grant update (navn, rolle, telefon, mat, tech_personlig) on table public.band_members to authenticated;
grant select, delete on table public.band_invites to authenticated;
