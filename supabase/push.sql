-- Web Push til bandleder og admin.
-- Kjør filen hvis databasen allerede finnes. Nye installasjoner har det i schema.sql.
--
-- Arrangørens forespørsel er en rad i public.bookings med status inquiry.
-- Settlisten er uavklart når setlists.bekreftet_at er tom.
--
-- Etterpå:
-- 1. Deploy supabase/functions/send-push med --no-verify-jwt.
-- 2. Legg VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT og PUSH_DISPATCH_SECRET
--    inn som secrets. Nøkkelparet for demo ligger i supabase/.vapid.env.
-- 3. Fyll private.push_settings med offentlig nøkkel, funksjons-URL og samme hemmelighet.
-- 4. Aktiver pg_net og pg_cron, og kjør denne filen på nytt så timeren blir lagt inn.

create schema if not exists private;

create table if not exists public.user_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

create index if not exists user_push_subscriptions_user_idx
  on public.user_push_subscriptions (user_id);

comment on table public.user_push_subscriptions is
  'Web Push-abonnement for én enhet. Bare bandleder og admin får lagre raden.';

create table if not exists public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  url text not null,
  dedupe_key text not null unique,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

comment on table public.push_outbox is
  'Varsler som venter på utsending. Klienten leser ikke tabellen.';

create table if not exists private.push_settings (
  id boolean primary key default true check (id),
  vapid_public_key text not null default '',
  vapid_subject text not null default 'mailto:booking@amundsen.studio',
  dispatch_url text not null default '',
  dispatch_secret text not null default ''
);

insert into private.push_settings (id)
values (true)
on conflict (id) do nothing;

alter table public.user_push_subscriptions enable row level security;
alter table public.push_outbox enable row level security;

drop policy if exists user_push_subscriptions_read_own on public.user_push_subscriptions;
create policy user_push_subscriptions_read_own on public.user_push_subscriptions
for select to authenticated
using (user_id = auth.uid());

grant select on table public.user_push_subscriptions to authenticated;

create or replace function public.can_receive_band_push()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.band_members m
    where m.user_id = auth.uid()
  );
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

create or replace function public.push_vapid_public_key()
returns text
language sql
stable
security definer
set search_path = public, private
as $$
  select vapid_public_key from private.push_settings where id;
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

create or replace function public.delete_push_subscription(p_endpoint text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Logg inn for å skru av varsler.';
  end if;
  if p_endpoint is null or btrim(p_endpoint) = '' then
    delete from public.user_push_subscriptions where user_id = auth.uid();
  else
    delete from public.user_push_subscriptions
    where user_id = auth.uid()
      and endpoint = p_endpoint;
  end if;
end;
$$;

create or replace function public.booking_request_for_me(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if auth.uid() is null or not public.can_receive_band_push() then
    return null;
  end if;

  select jsonb_build_object(
    'id', b.id,
    'artist_navn', a.navn,
    'dato', b.dato,
    'arrangor_navn', b.arrangor_navn,
    'organisasjon', b.organisasjon,
    'kontaktperson', b.kontaktperson,
    'epost', b.epost,
    'telefon', b.telefon,
    'spillested', b.spillested,
    'notater', b.notater
  )
  into result
  from public.bookings b
  join public.artists a on a.id = b.artist_id
  where b.id = p_id
    and b.status = 'inquiry'
    and auth.uid() in (select public.push_recipient_ids(b.artist_id));

  return result;
end;
$$;

create or replace function public.dispatch_push_outbox()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  settings private.push_settings%rowtype;
begin
  select * into settings from private.push_settings where id;
  if settings.dispatch_url is null or btrim(settings.dispatch_url) = '' then
    return;
  end if;
  if settings.dispatch_secret is null or btrim(settings.dispatch_secret) = '' then
    return;
  end if;
  perform net.http_post(
    url := settings.dispatch_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', settings.dispatch_secret
    ),
    body := '{}'::jsonb
  );
exception
  when others then
    raise warning 'Push-utsending ble ikke startet: %', sqlerrm;
end;
$$;

create or replace function public.enqueue_booking_request_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient uuid;
  who text;
  when_label text;
begin
  if new.status is distinct from 'inquiry' then
    return new;
  end if;

  who := coalesce(nullif(btrim(new.arrangor_navn), ''), nullif(btrim(new.spillested), ''), 'En arrangør');
  when_label := to_char(new.dato, 'DD.MM.YYYY');

  for recipient in
    select r.user_id
    from public.push_recipient_ids(new.artist_id) as r(user_id)
    where exists (
      select 1
      from public.user_push_subscriptions s
      where s.user_id = r.user_id
    )
  loop
    insert into public.push_outbox (user_id, title, body, url, dedupe_key)
    values (
      recipient,
      'Ny bookingforespørsel!',
      who || ' har sendt en forespørsel for ' || when_label || '. Klikk for å se detaljer.',
      '/artist/foresporsler/' || new.id::text,
      'booking:' || new.id::text || ':' || recipient::text
    )
    on conflict (dedupe_key) do nothing;
  end loop;

  perform public.dispatch_push_outbox();
  return new;
exception
  when others then
    raise warning 'Push-varsel for booking ble ikke lagt i kø: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists bookings_enqueue_push on public.bookings;
create trigger bookings_enqueue_push
after insert on public.bookings
for each row
execute function public.enqueue_booking_request_push();

create or replace function public.enqueue_setlist_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  yesterday date;
  gig record;
  recipient uuid;
begin
  perform public.dispatch_push_outbox();

  if extract(hour from timezone('Europe/Oslo', now())) <> 10 then
    return;
  end if;

  yesterday := (timezone('Europe/Oslo', now()))::date - 1;

  for gig in
    select g.id, g.artist_id
    from public.gigs g
    left join public.setlists s on s.gig_id = g.id
    where g.dato = yesterday
      and (s.gig_id is null or s.bekreftet_at is null)
  loop
    for recipient in
      select r.user_id
      from public.push_recipient_ids(gig.artist_id) as r(user_id)
      where exists (
        select 1
        from public.user_push_subscriptions s
        where s.user_id = r.user_id
      )
    loop
      insert into public.push_outbox (user_id, title, body, url, dedupe_key)
      values (
        recipient,
        'Bekreft gårsdagens settliste',
        'Husket dere å bekrefte låtene fra konserten i går? Klikk for å godkjenne TONO-rapporten.',
        '/artist/gigs/' || gig.id::text || '/settliste',
        'setlist:' || gig.id::text || ':' || yesterday::text || ':' || recipient::text
      )
      on conflict (dedupe_key) do nothing;
    end loop;
  end loop;

  perform public.dispatch_push_outbox();
end;
$$;

revoke all on function public.can_receive_band_push() from public;
revoke all on function public.push_recipient_ids(uuid) from public;
revoke all on function public.push_vapid_public_key() from public;
revoke all on function public.save_push_subscription(text, text, text) from public;
revoke all on function public.delete_push_subscription(text) from public;
revoke all on function public.booking_request_for_me(uuid) from public;
revoke all on function public.dispatch_push_outbox() from public;
revoke all on function public.enqueue_booking_request_push() from public;
revoke all on function public.enqueue_setlist_reminders() from public;

grant execute on function public.can_receive_band_push() to authenticated;
grant execute on function public.push_vapid_public_key() to anon, authenticated;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;
grant execute on function public.delete_push_subscription(text) to authenticated;
grant execute on function public.booking_request_for_me(uuid) to authenticated;

do $cron$
begin
  if exists (select 1 from cron.job where jobname = 'lavdi-push-hourly') then
    perform cron.unschedule('lavdi-push-hourly');
  end if;
  perform cron.schedule(
    'lavdi-push-hourly',
    '0 * * * *',
    'select public.enqueue_setlist_reminders()'
  );
exception
  when others then
    raise notice 'pg_cron er ikke aktivert, så påminnelsen kl. 10 ble ikke lagt inn: %', sqlerrm;
end;
$cron$;
