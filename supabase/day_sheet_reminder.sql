-- Påminnelse til arrangør 30 dager før konsert hvis dagskjema mangler.
-- Daglig via pg_cron → enqueue → dispatch-mail (Resend).
-- Trygt å kjøre på nytt.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create schema if not exists private;

create table if not exists private.mail_settings (
  id boolean primary key default true check (id),
  dispatch_url text not null default '',
  dispatch_secret text not null default '',
  auth_bearer text not null default ''
);

insert into private.mail_settings (id)
values (true)
on conflict (id) do nothing;

-- Fyll inn URL + anon-nøkkel (offentlig) hvis tomt.
update private.mail_settings
set
  dispatch_url = coalesce(nullif(btrim(dispatch_url), ''),
    'https://wcoxvjncbtrputurpqvt.supabase.co/functions/v1/dispatch-mail'),
  auth_bearer = coalesce(nullif(btrim(auth_bearer), ''),
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indjb3h2am5jYnRycHV0dXJwcXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3NDAwMDgsImV4cCI6MjEwNzMxNjAwOH0.JuyhvElNZm7BUvAi1t9woykHXOirYLFh58glgDHy29Y')
where id;

create or replace function public.enqueue_day_sheet_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  artist_name text;
  when_label text;
  recipient text;
  site text := 'https://www.lavdi.no';
  day_url text;
  today_oslo date := (timezone('Europe/Oslo', now()))::date;
  queued int := 0;
  inserted int;
begin
  for b in
    select *
    from public.bookings
    where status = 'confirmed'
      and coalesce(dagskjema, false) = false
      and dag_token is not null
      and btrim(dag_token) <> ''
      -- Fra og med fristdagen (30 dager før), én gang via dedupe.
      and dato - 30 <= today_oslo
      and dato > today_oslo
  loop
    recipient := lower(btrim(coalesce(b.epost, '')));
    if recipient = '' or position('@' in recipient) = 0 then
      continue;
    end if;

    select a.navn into artist_name
    from public.artists a
    where a.id = b.artist_id;

    when_label := to_char(b.dato, 'DD.MM.YYYY');
    day_url := site || '/arrangor/dag/' || b.dag_token;

    insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
    values (
      recipient,
      'Påminnelse: fyll ut dagskjema',
      'Hei'
        || case
             when nullif(btrim(b.kontaktperson), '') is null then ''
             else ' ' || btrim(b.kontaktperson)
           end
        || ','
        || chr(10) || chr(10)
        || 'Dette er en påminnelse om å fylle ut dagskjema for konserten med '
        || coalesce(nullif(btrim(artist_name), ''), 'artisten')
        || ' '
        || when_label
        || '.'
        || chr(10) || chr(10)
        || 'Fristen er 30 dager før konserten. Skjemaet er fortsatt ikke levert.'
        || chr(10) || chr(10)
        || 'Fyll ut her:'
        || chr(10)
        || day_url
        || chr(10) || chr(10)
        || 'Mvh'
        || chr(10)
        || 'Lávdi / Amundsen Studio',
      '',
      'day-sheet-reminder:' || b.id::text
    )
    on conflict (dedupe_key) do nothing;

    get diagnostics inserted = row_count;
    queued := queued + inserted;
  end loop;

  return queued;
end;
$$;

create or replace function public.dispatch_mail_outbox()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  settings private.mail_settings%rowtype;
  headers jsonb;
begin
  select * into settings from private.mail_settings where id;
  if settings.dispatch_url is null or btrim(settings.dispatch_url) = '' then
    return;
  end if;
  if settings.auth_bearer is null or btrim(settings.auth_bearer) = '' then
    return;
  end if;

  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || btrim(settings.auth_bearer)
  );
  if nullif(btrim(settings.dispatch_secret), '') is not null then
    headers := headers || jsonb_build_object('x-mail-secret', btrim(settings.dispatch_secret));
  end if;

  perform net.http_post(
    url := btrim(settings.dispatch_url),
    headers := headers,
    body := '{}'::jsonb
  );
exception
  when others then
    raise warning 'E-post-utsending ble ikke startet: %', sqlerrm;
end;
$$;

create or replace function public.run_day_sheet_reminder_job()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.enqueue_day_sheet_reminders();
  -- Reise-påminnelse defineres i travel_reminder.sql (no-op hvis den mangler).
  begin
    perform public.enqueue_travel_reminders();
  exception
    when undefined_function then
      null;
  end;
  perform public.dispatch_mail_outbox();
end;
$$;

revoke all on function public.enqueue_day_sheet_reminders() from public;
revoke all on function public.dispatch_mail_outbox() from public;
revoke all on function public.run_day_sheet_reminder_job() from public;
grant execute on function public.enqueue_day_sheet_reminders() to service_role;
grant execute on function public.dispatch_mail_outbox() to service_role;
grant execute on function public.run_day_sheet_reminder_job() to service_role;

-- Daglig kl. 07:00 UTC (08/09 Oslo). Idempotent via dedupe_key.
do $cron$
begin
  if exists (select 1 from cron.job where jobname = 'lavdi-day-sheet-reminders') then
    perform cron.unschedule('lavdi-day-sheet-reminders');
  end if;
  perform cron.schedule(
    'lavdi-day-sheet-reminders',
    '0 7 * * *',
    'select public.run_day_sheet_reminder_job()'
  );
exception
  when others then
    raise notice 'pg_cron er ikke aktivert, så dagskjema-påminnelsen ble ikke lagt inn: %', sqlerrm;
end;
$cron$;
