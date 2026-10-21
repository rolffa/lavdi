-- Påminnelse til arrangør 7 dager etter bekreftet konsert hvis reiseinfo mangler.
-- Kjøres daglig sammen med dagskjema-jobben (idempotent via dedupe_key).
-- Trygt å kjøre på nytt.

create or replace function public.enqueue_travel_reminders()
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
  travel_url text;
  today_oslo date := (timezone('Europe/Oslo', now()))::date;
  confirmed_day date;
  queued int := 0;
  inserted int;
begin
  for b in
    select *
    from public.bookings
    where status = 'confirmed'
      and reise_token is not null
      and btrim(reise_token) <> ''
      and (
        length(btrim(coalesce(flyplass, ''))) = 0
        or length(btrim(coalesce(avstand, ''))) = 0
      )
      and dato > today_oslo
  loop
    confirmed_day := (
      timezone('Europe/Oslo', coalesce(b.bekreftet_at, b.admin_signert_at))
    )::date;
    if confirmed_day is null then
      continue;
    end if;
    -- Fra og med 7 dager etter bekreftelse/signering, én gang via dedupe.
    if confirmed_day + 7 > today_oslo then
      continue;
    end if;

    recipient := lower(btrim(coalesce(b.epost, '')));
    if recipient = '' or position('@' in recipient) = 0 then
      continue;
    end if;

    select a.navn into artist_name
    from public.artists a
    where a.id = b.artist_id;

    when_label := to_char(b.dato, 'DD.MM.YYYY');
    travel_url := site || '/arrangor/reise/' || b.reise_token;

    insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
    values (
      recipient,
      'Påminnelse: fyll ut reiseinfo',
      'Hei'
        || case
             when nullif(btrim(b.kontaktperson), '') is null then ''
             else ' ' || btrim(b.kontaktperson)
           end
        || ','
        || chr(10) || chr(10)
        || 'Det er gått en uke siden konserten med '
        || coalesce(nullif(btrim(artist_name), ''), 'artisten')
        || ' '
        || when_label
        || ' ble bekreftet, og reiseinfo er fortsatt ikke fylt ut.'
        || chr(10) || chr(10)
        || 'Artisten trenger nærmeste flyplass, avstand til spillested og eventuell mer info før reisen kan bestilles.'
        || chr(10) || chr(10)
        || 'Fyll ut her:'
        || chr(10)
        || travel_url
        || chr(10) || chr(10)
        || 'Mvh'
        || chr(10)
        || 'Lávdi / Amundsen Studio',
      '',
      'travel-reminder:' || b.id::text
    )
    on conflict (dedupe_key) do nothing;

    get diagnostics inserted = row_count;
    queued := queued + inserted;
  end loop;

  return queued;
end;
$$;

revoke all on function public.enqueue_travel_reminders() from public;
grant execute on function public.enqueue_travel_reminders() to service_role;

-- Utvid den daglige jobben til også å kølegge reise-påminnelser.
create or replace function public.run_day_sheet_reminder_job()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.enqueue_day_sheet_reminders();
  perform public.enqueue_travel_reminders();
  perform public.dispatch_mail_outbox();
end;
$$;
