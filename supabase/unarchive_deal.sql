-- Ta en arkivert, avslått forespørsel ut av arkivet igjen.
-- Trygt å kjøre på nytt.

create or replace function public.admin_unarchive_deal(p_pin text, p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;

  update public.bookings
  set arkivert_at = null
  where id = p_booking_id
    and status = 'declined'
    and arkivert_at is not null;

  if not found then
    raise exception 'Forespørselen er ikke i arkivet';
  end if;

  update public.artist_offers
  set status = 'declined'
  where booking_id = p_booking_id
    and status = 'archived';
end;
$$;

revoke all on function public.admin_unarchive_deal(text, uuid) from public;
grant execute on function public.admin_unarchive_deal(text, uuid) to anon, authenticated;
