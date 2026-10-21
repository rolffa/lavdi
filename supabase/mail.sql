-- E-postkø for bandleder/admin. Utsending skjer via Edge Function
-- supabase/functions/dispatch-mail (Resend).

create table if not exists public.mail_outbox (
  id uuid primary key default gen_random_uuid(),
  to_email text not null,
  subject text not null,
  body text not null,
  url text not null default '',
  dedupe_key text not null unique,
  created_at timestamptz not null default now()
);

alter table public.mail_outbox enable row level security;
revoke all on table public.mail_outbox from anon, authenticated;

comment on table public.mail_outbox is
  'E-post til bandmedlemmer. Ingen mailserver sender radene videre.';

create or replace function public.band_leader_emails(p_artist_id uuid)
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select distinct lower(btrim(u.email))
  from public.band_members m
  join public.bands b on b.id = m.band_id
  join auth.users u on u.id = m.user_id
  where b.artist_id = p_artist_id
    and m.user_id is not null
    and u.email is not null
    and btrim(u.email) <> '';
$$;

revoke all on function public.band_leader_emails(uuid) from public;
grant execute on function public.band_leader_emails(uuid) to authenticated;

create or replace function public.enqueue_booking_request_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient text;
  who text;
  when_label text;
begin
  if tg_op = 'INSERT' or new.status is distinct from 'with_artist' then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and old.status = 'with_artist'
     and old.svarfrist is not distinct from new.svarfrist then
    return new;
  end if;

  who := coalesce(nullif(btrim(new.arrangor_navn), ''), nullif(btrim(new.spillested), ''), 'En arrangør');
  when_label := to_char(new.dato, 'DD.MM.YYYY');

  for recipient in
    select public.band_leader_emails(new.artist_id)
  loop
    insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
    values (
      recipient,
      'Ny bookingforespørsel!',
      who || ' har sendt en forespørsel for ' || when_label || '. Klikk for å se detaljer.',
      '/min-side',
      'offer:' || new.id::text || ':' || coalesce(new.svarfrist::text, '') || ':' || recipient
    )
    on conflict (dedupe_key) do nothing;
  end loop;

  return new;
exception
  when others then
    raise warning 'E-post til bandleder ble ikke lagt i kø: %', sqlerrm;
    return new;
end;
$$;

create or replace function public.enqueue_setlist_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  yesterday date;
  gig record;
  recipient text;
begin
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
      select public.band_leader_emails(gig.artist_id)
    loop
      insert into public.mail_outbox (to_email, subject, body, url, dedupe_key)
      values (
        recipient,
        'Bekreft gårsdagens settliste',
        'Husket dere å bekrefte låtene fra konserten i går? Klikk for å godkjenne TONO-rapporten.',
        '/artist/gigs/' || gig.id::text || '/settliste',
        'setlist:' || gig.id::text || ':' || yesterday::text || ':' || recipient
      )
      on conflict (dedupe_key) do nothing;
    end loop;
  end loop;
end;
$$;
