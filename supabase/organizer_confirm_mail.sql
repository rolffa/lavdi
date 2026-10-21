-- E-post til arrangør når admin bekrefter konsert (reise + dagskjema).
-- Trygt å kjøre på nytt.

create or replace function public.enqueue_organizer_confirm_mail()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  artist_name text;
  when_label text;
  recipient text;
  site text := 'https://www.lavdi.no';
  travel_url text;
  day_url text;
  day_due text;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if new.status is distinct from 'confirmed' then
    return new;
  end if;
  if old.status is not distinct from 'confirmed' then
    return new;
  end if;

  recipient := lower(btrim(coalesce(new.epost, '')));
  if recipient = '' or position('@' in recipient) = 0 then
    return new;
  end if;
  if new.reise_token is null or btrim(new.reise_token) = '' then
    return new;
  end if;
  if new.dag_token is null or btrim(new.dag_token) = '' then
    return new;
  end if;

  select a.navn into artist_name
  from public.artists a
  where a.id = new.artist_id;

  when_label := to_char(new.dato, 'DD.MM.YYYY');
  day_due := to_char(new.dato - 30, 'DD.MM.YYYY');
  travel_url := site || '/arrangor/reise/' || new.reise_token;
  day_url := site || '/arrangor/dag/' || new.dag_token;

  insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
  values (
    recipient,
    'Konserten er bekreftet – fyll ut reiseinfo og dagskjema',
    'Hei'
      || case
           when nullif(btrim(new.kontaktperson), '') is null then ''
           else ' ' || btrim(new.kontaktperson)
         end
      || ','
      || chr(10) || chr(10)
      || 'Konserten med '
      || coalesce(nullif(btrim(artist_name), ''), 'artisten')
      || ' '
      || when_label
      || ' er bekreftet.'
      || chr(10) || chr(10)
      || '1) Fyll ut reiseinfo (flyplass, avstand og mer):'
      || chr(10)
      || travel_url
      || chr(10) || chr(10)
      || '2) Fyll ut dagskjema (lydprøve, showstart, hotell m.m.).'
      || chr(10)
      || 'Frist: '
      || day_due
      || ' (30 dager før konserten).'
      || chr(10)
      || day_url
      || chr(10) || chr(10)
      || 'Mvh'
      || chr(10)
      || 'Lávdi / Amundsen Studio',
    '',
    'organizer-confirm:' || new.id::text
  )
  on conflict (dedupe_key) do nothing;

  return new;
exception
  when others then
    raise warning 'Arrangør-mail ved bekreftelse ble ikke lagt i kø: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists bookings_enqueue_organizer_confirm_mail on public.bookings;
create trigger bookings_enqueue_organizer_confirm_mail
after update of status on public.bookings
for each row
execute function public.enqueue_organizer_confirm_mail();

revoke all on function public.enqueue_organizer_confirm_mail() from public;
