-- Admin-varsel når arrangør sender bookingforespørsel (status inquiry).
-- Ingen lenke — bare beskjed om at forespørsel har kommet.
-- Trygt å kjøre på nytt.

alter table public.mail_outbox
  add column if not exists sent_at timestamptz;

create or replace function public.enqueue_admin_inquiry_mail()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  artist_name text;
  who text;
  when_label text;
  venue text;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;
  if new.status is distinct from 'inquiry' then
    return new;
  end if;

  select a.navn into artist_name
  from public.artists a
  where a.id = new.artist_id;

  who := coalesce(
    nullif(btrim(new.arrangor_navn), ''),
    nullif(btrim(new.organisasjon), ''),
    'En arrangør'
  );
  when_label := to_char(new.dato, 'DD.MM.YYYY');
  venue := coalesce(nullif(btrim(new.spillested), ''), 'ukjent spillested');

  insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
  values (
    'post@amundsenstudio.no',
    'Ny bookingforespørsel',
    'En ny bookingforespørsel har kommet inn.'
      || chr(10) || chr(10)
      || 'Artist: ' || coalesce(nullif(btrim(artist_name), ''), 'ukjent')
      || chr(10)
      || 'Dato: ' || when_label
      || chr(10)
      || 'Arrangør: ' || who
      || chr(10)
      || 'Spillested: ' || venue
      || chr(10) || chr(10)
      || 'Åpne adminportalen for å behandle forespørselen.',
    '',
    'admin-inquiry:' || new.id::text
  )
  on conflict (dedupe_key) do nothing;

  return new;
exception
  when others then
    raise warning 'Admin-mail for forespørsel ble ikke lagt i kø: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists bookings_enqueue_admin_mail on public.bookings;
create trigger bookings_enqueue_admin_mail
after insert on public.bookings
for each row
execute function public.enqueue_admin_inquiry_mail();

revoke all on function public.enqueue_admin_inquiry_mail() from public;
