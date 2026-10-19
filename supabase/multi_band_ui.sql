-- Bandvelger + kombinert kalender for musikere i flere band.
-- Forutsetter multi_band_membership.sql (user_active_band, current_band_id, set_active_band).

-- Aktiv artist følger aktivt band (ikke bare første medlemskap).
create or replace function public.current_artist_id()
returns uuid
language sql
stable
security definer
set search_path = public, private
as $$
  select coalesce(
    (select artist_id from private.admin_artist_view where auth_user_id = auth.uid()),
    (
      select b.artist_id
      from public.bands b
      where b.id = public.current_band_id()
    ),
    (select artist_id from private.artist_logins where auth_user_id = auth.uid()),
    (
      select b.artist_id
      from public.band_members m
      join public.bands b on b.id = m.band_id
      where m.user_id = auth.uid()
      order by m.created_at desc nulls last
      limit 1
    )
  );
$$;

-- Oversikt over alle band brukeren er medlem i.
create or replace function public.my_bands()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_active uuid := public.current_band_id();
  v_result jsonb;
begin
  if auth.uid() is null then
    return '[]'::jsonb;
  end if;

  if exists (
    select 1 from private.admin_artist_view v where v.auth_user_id = auth.uid()
  ) then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'band_id', b.id,
          'band_navn', b.navn,
          'artist_id', a.id,
          'artist_navn', a.navn,
          'rolle', 'Admin',
          'er_aktiv', true
        )
      ),
      '[]'::jsonb
    )
    into v_result
    from private.admin_artist_view v
    join public.bands b on b.artist_id = v.artist_id
    join public.artists a on a.id = b.artist_id
    where v.auth_user_id = auth.uid();
    return coalesce(v_result, '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'band_id', b.id,
        'band_navn', b.navn,
        'artist_id', a.id,
        'artist_navn', a.navn,
        'rolle', coalesce(nullif(trim(m.rolle), ''), 'Medlem'),
        'er_aktiv', b.id = v_active
      )
      order by b.navn
    ),
    '[]'::jsonb
  )
  into v_result
  from public.band_members m
  join public.bands b on b.id = m.band_id
  join public.artists a on a.id = b.artist_id
  where m.user_id = auth.uid();

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.my_bands() from public;
grant execute on function public.my_bands() to authenticated;

-- Kombinert kalender: ledige og opptatte dager på tvers av alle medlemskap.
create or replace function public.my_combined_calendar(p_from date, p_to date)
returns table (
  dato date,
  band_id uuid,
  band_navn text,
  artist_id uuid,
  er_tilgjengelig boolean,
  er_booket boolean,
  gig_id uuid,
  gig_tittel text
)
language sql
stable
security definer
set search_path = public, private
as $$
  with my_bands as (
    select b.id as band_id, b.navn as band_navn, b.artist_id
    from public.band_members m
    join public.bands b on b.id = m.band_id
    where m.user_id = auth.uid()
    union
    select b.id, b.navn, b.artist_id
    from private.admin_artist_view v
    join public.bands b on b.artist_id = v.artist_id
    where v.auth_user_id = auth.uid()
  )
  select
    a.date as dato,
    mb.band_id,
    mb.band_navn,
    mb.artist_id,
    true as er_tilgjengelig,
    false as er_booket,
    null::uuid as gig_id,
    null::text as gig_tittel
  from public.artist_availability a
  join my_bands mb on mb.band_id = a.band_id
  where a.status = 'available'
    and a.date between p_from and p_to
    and not exists (
      select 1
      from public.gigs g
      where g.artist_id = mb.artist_id
        and g.dato = a.date
    )
  union all
  select
    g.dato,
    mb.band_id,
    mb.band_navn,
    mb.artist_id,
    false,
    true,
    g.id,
    nullif(
      trim(
        coalesce(
          g.produksjon ->> 'arrangementsnavn',
          g.arrangor ->> 'spillested',
          ''
        )
      ),
      ''
    )
  from public.gigs g
  join my_bands mb on mb.artist_id = g.artist_id
  where g.dato between p_from and p_to;
$$;

revoke all on function public.my_combined_calendar(date, date) from public;
grant execute on function public.my_combined_calendar(date, date) to authenticated;
