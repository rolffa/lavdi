-- Admin-logg under Artister: invitasjoner og aktiveringer.
-- Trygt å kjøre på nytt.

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  message text not null,
  artist_id uuid references public.artists (id) on delete set null,
  invite_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists admin_notifications_created_idx
  on public.admin_notifications (created_at desc);

comment on table public.admin_notifications is
  'Oppdateringer for admin (invitasjon, aktivering). Slettes manuelt når lest.';

alter table public.admin_notifications enable row level security;

create or replace function public.admin_notification_label(p_email text)
returns text
language sql
immutable
as $$
  select initcap(split_part(lower(btrim(coalesce(p_email, ''))), '@', 1));
$$;

create or replace function public.log_admin_notification(
  p_kind text,
  p_message text,
  p_artist_id uuid default null,
  p_invite_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.admin_notifications (kind, message, artist_id, invite_id)
  values (p_kind, p_message, p_artist_id, p_invite_id)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.band_invite_admin_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_artist_id uuid;
  v_artist text;
  v_who text;
begin
  select b.artist_id, a.navn
  into v_artist_id, v_artist
  from public.bands b
  left join public.artists a on a.id = b.artist_id
  where b.id = new.band_id;

  v_who := public.admin_notification_label(new.email);
  if v_who = '' then
    v_who := new.email;
  end if;

  if tg_op = 'INSERT'
     or (tg_op = 'UPDATE' and old.accepted_at is null and new.accepted_at is null
         and (old.token is distinct from new.token or old.rolle is distinct from new.rolle))
  then
    perform public.log_admin_notification(
      'invite_pending',
      v_who
        || ' er invitert'
        || case
             when nullif(btrim(coalesce(v_artist, '')), '') is null then ''
             else ' til ' || btrim(v_artist)
           end
        || ', venter på aktivering.',
      v_artist_id,
      new.id
    );
  elsif tg_op = 'UPDATE'
        and old.accepted_at is null
        and new.accepted_at is not null
  then
    perform public.log_admin_notification(
      'invite_activated',
      'Profil er opprettet for '
        || v_who
        || case
             when nullif(btrim(coalesce(v_artist, '')), '') is null then ''
             else ' (' || btrim(v_artist) || ')'
           end
        || '.',
      v_artist_id,
      new.id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists band_invites_admin_notify on public.band_invites;
create trigger band_invites_admin_notify
after insert or update on public.band_invites
for each row
execute function public.band_invite_admin_notify();

create or replace function public.admin_list_notifications(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'kind', n.kind,
        'message', n.message,
        'artist_id', n.artist_id,
        'invite_id', n.invite_id,
        'created_at', n.created_at
      )
      order by n.created_at desc
    )
    from (
      select *
      from public.admin_notifications
      order by created_at desc
      limit 100
    ) n
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_dismiss_notification(
  p_pin text,
  p_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  delete from public.admin_notifications where id = p_id;
end;
$$;

revoke all on function public.admin_notification_label(text) from public;
revoke all on function public.log_admin_notification(text, text, uuid, uuid) from public;
revoke all on function public.band_invite_admin_notify() from public;
revoke all on function public.admin_list_notifications(text) from public;
revoke all on function public.admin_dismiss_notification(text, uuid) from public;

grant execute on function public.admin_list_notifications(text) to anon, authenticated;
grant execute on function public.admin_dismiss_notification(text, uuid) to anon, authenticated;
