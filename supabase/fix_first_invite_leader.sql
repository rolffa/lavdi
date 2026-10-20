-- Første ekte invitasjon blir bandleder.
-- Autogenererte «tomme» created_by-seter telles ikke som medlemmer.
-- Trygt å kjøre på nytt.

create or replace function public.accept_band_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  v_invite public.band_invites;
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_member uuid;
  v_leader boolean;
  v_has_member boolean;
begin
  if auth.uid() is null then
    raise exception 'Åpne lenken i e-posten for å aktivere kontoen.';
  end if;
  select * into v_invite from public.band_invites where token = p_token;
  if not found then
    raise exception 'Invitasjonen finnes ikke.';
  end if;
  if lower(v_invite.email) <> v_email then
    raise exception 'Lenken er sendt til en annen e-postadresse.';
  end if;
  if exists (
    select 1 from public.band_members
    where user_id = auth.uid() and band_id = v_invite.band_id
  ) then
    update public.band_invites set accepted_at = now() where id = v_invite.id;
    perform public.set_active_band(v_invite.band_id);
    select id into v_member
    from public.band_members
    where user_id = auth.uid() and band_id = v_invite.band_id
    limit 1;
    return v_member;
  end if;

  -- Tomme auto-seter (created_by uten profil) eller user_id null teller ikke.
  select exists (
    select 1
    from public.band_members m
    join public.bands b on b.id = m.band_id
    where m.band_id = v_invite.band_id
      and m.user_id is not null
      and not (
        m.user_id is not distinct from b.created_by
        and m.er_leder
        and coalesce(nullif(trim(m.telefon), ''), '') = ''
        and coalesce(nullif(trim(m.mat), ''), '') = ''
        and coalesce(nullif(trim(m.tech_personlig), ''), '') = ''
      )
  ) into v_has_member;

  v_leader :=
    (not v_has_member)
    or lower(btrim(v_invite.rolle)) in ('bandleder', 'leder');

  if not v_has_member then
    delete from public.band_members m
    using public.bands b
    where m.band_id = b.id
      and m.band_id = v_invite.band_id
      and (
        m.user_id is null
        or (
          m.user_id is not distinct from b.created_by
          and m.er_leder
          and coalesce(nullif(trim(m.telefon), ''), '') = ''
          and coalesce(nullif(trim(m.mat), ''), '') = ''
          and coalesce(nullif(trim(m.tech_personlig), ''), '') = ''
        )
      );
  end if;

  insert into public.band_members (band_id, user_id, rolle, er_leder)
  values (
    v_invite.band_id,
    auth.uid(),
    case when not v_has_member then 'Bandleder' else v_invite.rolle end,
    v_leader
  )
  on conflict (band_id, user_id) do update
    set rolle = case
          when not v_has_member then 'Bandleder'
          else coalesce(nullif(public.band_members.rolle, ''), excluded.rolle)
        end,
        er_leder = public.band_members.er_leder or excluded.er_leder
  returning id into v_member;

  update public.band_invites set accepted_at = now() where id = v_invite.id;
  perform public.set_active_band(v_invite.band_id);
  return v_member;
end;
$$;

revoke all on function public.accept_band_invite(text) from public;
grant execute on function public.accept_band_invite(text) to authenticated;

-- Rydd eksisterende tomme created_by-bandleder-seter der bandet allerede har
-- andre medlemmer eller ventende invitasjoner.
delete from public.band_members m
using public.bands b
where m.band_id = b.id
  and b.created_by is not null
  and m.user_id = b.created_by
  and m.er_leder
  and coalesce(nullif(trim(m.telefon), ''), '') = ''
  and coalesce(nullif(trim(m.mat), ''), '') = ''
  and coalesce(nullif(trim(m.tech_personlig), ''), '') = ''
  and (
    exists (
      select 1 from public.band_members o
      where o.band_id = b.id and o.id <> m.id
    )
    or exists (
      select 1 from public.band_invites i
      where i.band_id = b.id and i.accepted_at is null
    )
  );
