-- Tilgjengelighetskalender styrt av bandet. Uten rad er datoen utilgjengelig.
-- Kjør denne hvis schema.sql allerede er lagt inn uten tabellen.

create table if not exists public.artist_availability (
  id uuid primary key default gen_random_uuid(),
  band_id uuid not null references public.bands (id) on delete cascade,
  date date not null,
  status text not null check (status in ('available', 'unavailable')),
  unique (band_id, date)
);

comment on table public.artist_availability is 'Datoer bandet har markert. Ingen rad betyr utilgjengelig.';
comment on column public.artist_availability.status is 'available eller unavailable. Bekreftede jobber låses av gigs, uavhengig av raden.';

alter table public.artist_availability enable row level security;

drop policy if exists artist_availability_member_write on public.artist_availability;
create policy artist_availability_member_write on public.artist_availability
for all to authenticated
using (
  exists (
    select 1 from public.band_members m
    where m.band_id = artist_availability.band_id
      and m.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.band_members m
    where m.band_id = artist_availability.band_id
      and m.user_id = auth.uid()
  )
);

drop policy if exists artist_availability_public_read on public.artist_availability;
create policy artist_availability_public_read on public.artist_availability
for select to anon
using (status = 'available');

grant select, insert, update, delete on table public.artist_availability to authenticated;
grant select on table public.artist_availability to anon;

create or replace function public.availability_for_artist(
  p_artist_id uuid,
  p_from date,
  p_to date
)
returns table (dato date, er_tilgjengelig boolean, er_booket boolean)
language sql
stable
security definer
set search_path = public
as $$
  select a.date, true, false
  from public.artist_availability a
  join public.bands b on b.id = a.band_id
  where b.artist_id = p_artist_id
    and a.status = 'available'
    and a.date between p_from and p_to
    and not exists (
      select 1
      from public.gigs g
      where g.artist_id = p_artist_id
        and g.dato = a.date
    )
  union all
  select g.dato, false, true
  from public.gigs g
  where g.artist_id = p_artist_id
    and g.dato between p_from and p_to;
$$;

create or replace function public.save_artist_availability(
  p_dates date[],
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_band uuid;
begin
  if auth.uid() is null then
    raise exception 'Logg inn for å endre kalenderen';
  end if;
  if p_status not in ('available', 'unavailable') then
    raise exception 'Ugyldig status';
  end if;
  if p_dates is null or cardinality(p_dates) = 0 then
    return;
  end if;

  v_band := public.current_band_id();
  if v_band is null then
    raise exception 'Opprett bandet før du åpner kalenderen.';
  end if;
  if not exists (
    select 1 from public.band_members
    where band_id = v_band and user_id = auth.uid()
  ) then
    raise exception 'Bare bandet kan endre tilgjengeligheten';
  end if;

  if p_status = 'available' and exists (
    select 1
    from unnest(p_dates) as d
    join public.bands b on b.id = v_band
    join public.gigs g on g.artist_id = b.artist_id and g.dato = d
  ) then
    raise exception 'Datoen er opptatt av en bekreftet jobb';
  end if;

  insert into public.artist_availability (band_id, date, status)
  select v_band, d, p_status
  from unnest(p_dates) as d
  on conflict (band_id, date) do update
  set status = excluded.status;
end;
$$;

create or replace function public.bookings_require_available_date()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'inquiry' and not exists (
    select 1
    from public.artist_availability a
    join public.bands b on b.id = a.band_id
    where b.artist_id = new.artist_id
      and a.date = new.dato
      and a.status = 'available'
      and not exists (
        select 1
        from public.gigs g
        where g.artist_id = new.artist_id
          and g.dato = new.dato
      )
  ) then
    raise exception 'Datoen er ikke tilgjengelig for booking';
  end if;
  return new;
end;
$$;

revoke all on function public.availability_for_artist(uuid, date, date) from public;
grant execute on function public.availability_for_artist(uuid, date, date) to anon, authenticated;
revoke all on function public.save_artist_availability(date[], text) from public, anon;
grant execute on function public.save_artist_availability(date[], text) to authenticated;
