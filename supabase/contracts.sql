-- Konsertkontrakt: lagring av generert PDF + lesetilgang for artistband.
-- Trygt å kjøre på nytt.

alter table public.bookings
  add column if not exists contract_path text;

comment on column public.bookings.contract_path is
  'Sti i storage-bucket contracts for generert konsertkontrakt-PDF.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'contracts',
  'contracts',
  false,
  5242880,
  array['application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Bandmedlemmer (inkl. admin «se som artist») kan lese kontrakter for egen artist.
drop policy if exists contracts_member_read on storage.objects;
create policy contracts_member_read on storage.objects
for select to authenticated
using (
  bucket_id = 'contracts'
  and (storage.foldername(name))[1] = public.current_artist_id()::text
);

drop policy if exists contracts_member_write on storage.objects;
create policy contracts_member_write on storage.objects
for insert to authenticated
with check (
  bucket_id = 'contracts'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_artist_id()::text
);

drop policy if exists contracts_member_update on storage.objects;
create policy contracts_member_update on storage.objects
for update to authenticated
using (
  bucket_id = 'contracts'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_artist_id()::text
)
with check (
  bucket_id = 'contracts'
  and public.is_band_member()
  and (storage.foldername(name))[1] = public.current_artist_id()::text
);

create or replace function public.contract_payload_for_me(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_artist uuid := public.current_artist_id();
  b public.bookings%rowtype;
  artist_navn text;
  crew_count int;
begin
  if auth.uid() is null or v_artist is null then
    raise exception 'Logg inn';
  end if;

  select * into b from public.bookings where id = p_booking_id;
  if not found then
    return null;
  end if;
  if b.artist_id <> v_artist then
    raise exception 'Ingen tilgang';
  end if;
  if b.status not in ('accepted', 'admin_signed', 'confirmed') then
    raise exception 'Kontrakt er ikke klar ennå';
  end if;

  select a.navn into artist_navn from public.artists a where a.id = b.artist_id;

  select count(*)::int into crew_count
  from public.band_members m
  join public.bands band on band.id = m.band_id
  where band.artist_id = b.artist_id;

  return jsonb_build_object(
    'booking_id', b.id,
    'artist_navn', coalesce(artist_navn, ''),
    'dato', b.dato,
    'arrangor_navn', b.arrangor_navn,
    'organisasjon', b.organisasjon,
    'kontaktperson', b.kontaktperson,
    'epost', b.epost,
    'telefon', b.telefon,
    'spillested', b.spillested,
    'honorar', b.honorar,
    'contract_path', coalesce(b.contract_path, ''),
    'reisefolge', case
      when crew_count > 0 then crew_count::text || ' personer (inkl. crew)'
      else ''
    end,
    'lydprove', coalesce(nullif(btrim(b.lydprove), ''), nullif(btrim(b.oppmote), ''), ''),
    'showstart', coalesce(b.showstart, ''),
    'varighet', '',
    'fakturaadresse', '',
    'org_nr', '',
    'by', ''
  );
end;
$$;

create or replace function public.contract_payload_for_gig(p_gig_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking uuid;
begin
  select g.booking_id into v_booking
  from public.gigs g
  where g.id = p_gig_id
    and g.artist_id = public.current_artist_id();
  if v_booking is null then
    return null;
  end if;
  return public.contract_payload_for_me(v_booking);
end;
$$;

create or replace function public.set_booking_contract_path(
  p_booking_id uuid,
  p_path text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_artist uuid := public.current_artist_id();
begin
  if auth.uid() is null or v_artist is null then
    raise exception 'Logg inn';
  end if;
  update public.bookings
  set contract_path = nullif(trim(p_path), '')
  where id = p_booking_id
    and artist_id = v_artist
    and status in ('accepted', 'admin_signed', 'confirmed');
  if not found then
    raise exception 'Kunne ikke lagre kontraktsti';
  end if;
end;
$$;

-- Etter artist-godkjenning: hent booking_id fra offer.
create or replace function public.contract_payload_for_offer(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking uuid;
  v_artist uuid := public.current_artist_id();
begin
  if auth.uid() is null or v_artist is null then
    raise exception 'Logg inn';
  end if;
  select o.booking_id into v_booking
  from public.artist_offers o
  where o.id = p_offer_id
    and o.artist_id = v_artist
    and o.status = 'approved';
  if v_booking is null then
    return null;
  end if;
  return public.contract_payload_for_me(v_booking);
end;
$$;

revoke all on function public.contract_payload_for_me(uuid) from public;
revoke all on function public.contract_payload_for_gig(uuid) from public;
revoke all on function public.contract_payload_for_offer(uuid) from public;
revoke all on function public.set_booking_contract_path(uuid, text) from public;
grant execute on function public.contract_payload_for_me(uuid) to authenticated;
grant execute on function public.contract_payload_for_gig(uuid) to authenticated;
grant execute on function public.contract_payload_for_offer(uuid) to authenticated;
grant execute on function public.set_booking_contract_path(uuid, text) to authenticated;
