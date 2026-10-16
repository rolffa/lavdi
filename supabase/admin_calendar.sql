-- Admin-kalender for en database som allerede har schema.sql.
-- Trygt å kjøre på nytt.
--
-- Sett PIN etterpå, som database-eier:
--   select public.set_admin_pin('en-lang-kode');

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

create table if not exists private.admin_gate (
  id boolean primary key default true,
  pin_hash text not null,
  constraint admin_gate_singleton check (id)
);

comment on table private.admin_gate is 'PIN-hash for /admin/kalender. Ikke lesbar for anon.';

create or replace function public.set_admin_pin(p_pin text)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if p_pin is null or length(trim(p_pin)) < 4 then
    raise exception 'PIN må ha minst 4 tegn';
  end if;

  insert into private.admin_gate (id, pin_hash)
  values (true, crypt(trim(p_pin), gen_salt('bf')))
  on conflict (id) do update
  set pin_hash = excluded.pin_hash;
end;
$$;

create or replace function public.admin_check_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  return exists (
    select 1
    from private.admin_gate
    where crypt(coalesce(p_pin, ''), pin_hash) = pin_hash
  );
end;
$$;

create or replace function public.admin_set_availability(
  p_pin text,
  p_artist_id uuid,
  p_dato date,
  p_ledig boolean
)
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
begin
  if p_artist_id is null or p_dato is null or p_ledig is null then
    raise exception 'Artist og dato mangler';
  end if;

  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  if not exists (select 1 from public.artists where id = p_artist_id) then
    raise exception 'Fant ikke artisten';
  end if;

  if p_ledig and exists (
    select 1
    from public.gigs
    where artist_id = p_artist_id
      and dato = p_dato
  ) then
    raise exception 'Datoen er opptatt av en bekreftet jobb';
  end if;

  insert into public.availability (artist_id, dato, er_tilgjengelig)
  values (p_artist_id, p_dato, p_ledig)
  on conflict (artist_id, dato) do update
  set er_tilgjengelig = excluded.er_tilgjengelig;
end;
$$;

revoke all on function public.set_admin_pin(text) from public, anon, authenticated;
revoke all on function public.admin_check_pin(text) from public;
revoke all on function public.admin_set_availability(text, uuid, date, boolean) from public;
grant execute on function public.admin_check_pin(text) to anon, authenticated;
grant execute on function public.admin_set_availability(text, uuid, date, boolean) to anon, authenticated;
