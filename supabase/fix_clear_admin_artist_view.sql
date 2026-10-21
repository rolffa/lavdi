-- La klienten rydde «se som artist» uten PIN (kun egen auth-bruker).
-- Brukes når man går til Artist-portalen fra forsiden uten aktiv admin-økt.

create or replace function public.clear_my_admin_artist_view()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  delete from private.admin_artist_view where auth_user_id = auth.uid();
end;
$$;

revoke all on function public.clear_my_admin_artist_view() from public;
grant execute on function public.clear_my_admin_artist_view() to authenticated;
