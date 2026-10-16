-- Når artisten angrer avslag: ta forespørselen ut av arkiv og tilbake til aktiv.
-- Trygt å kjøre på nytt.

create or replace function public.undo_offer_decline(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  offer public.artist_offers%rowtype;
  deadline timestamptz;
begin
  if auth.uid() is null or public.current_artist_id() is null then
    raise exception 'Logg inn på nytt';
  end if;

  select * into offer
  from public.artist_offers
  where id = p_offer_id
    and artist_id = public.current_artist_id()
    and status = 'declined'
  for update;

  if not found then
    raise exception 'Forespørselen finnes ikke';
  end if;

  if exists (
    select 1 from public.artist_offers
    where artist_id = offer.artist_id
      and dato = offer.dato
      and status = 'pending'
      and id <> offer.id
  ) then
    raise exception 'Det ligger allerede et tilbud på denne datoen';
  end if;

  deadline := now() + interval '48 hours';

  update public.artist_offers
  set status = 'pending',
      avslag_kommentar = '',
      svarfrist = deadline
  where id = offer.id;

  if offer.booking_id is not null then
    update public.bookings
    set status = 'with_artist',
        avslag_kommentar = '',
        arkivert_at = null,
        sendt_artist_at = coalesce(sendt_artist_at, now()),
        svarfrist = deadline
    where id = offer.booking_id
      and status = 'declined';
  end if;
end;
$$;
