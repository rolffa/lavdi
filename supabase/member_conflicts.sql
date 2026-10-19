-- Medlemskonflikter på tvers av band: musiker booket i band A → varsel for band B.
-- Trygt å kjøre på nytt.

create or replace function public.member_conflicts_on_date(
  p_artist_id uuid,
  p_dato date
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with target_members as (
    select
      m.id as member_id,
      m.user_id,
      coalesce(nullif(trim(m.navn), ''), 'Medlem') as member_navn,
      coalesce(nullif(trim(m.rolle), ''), 'Medlem') as member_rolle,
      m.band_id as home_band_id
    from public.band_members m
    join public.bands b on b.id = m.band_id
    where b.artist_id = p_artist_id
      and m.user_id is not null
  ),
  conflicts as (
    select distinct
      tm.member_id,
      tm.member_navn,
      tm.member_rolle,
      ob.id as other_band_id,
      ob.navn as other_band_navn,
      oa.id as other_artist_id,
      oa.navn as other_artist_navn,
      g.id as gig_id,
      g.dato
    from target_members tm
    join public.band_members om
      on om.user_id = tm.user_id
     and om.band_id <> tm.home_band_id
    join public.bands ob on ob.id = om.band_id
    join public.artists oa on oa.id = ob.artist_id
    join public.gigs g
      on g.artist_id = ob.artist_id
     and g.dato = p_dato
    where ob.artist_id is distinct from p_artist_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'member_id', member_id,
        'member_navn', member_navn,
        'member_rolle', member_rolle,
        'other_band_id', other_band_id,
        'other_band_navn', other_band_navn,
        'other_artist_id', other_artist_id,
        'other_artist_navn', other_artist_navn,
        'gig_id', gig_id,
        'dato', dato
      )
      order by member_navn, other_band_navn
    ),
    '[]'::jsonb
  )
  from conflicts;
$$;

revoke all on function public.member_conflicts_on_date(uuid, date) from public;
grant execute on function public.member_conflicts_on_date(uuid, date) to authenticated;

create or replace function public.admin_member_conflicts_on_date(
  p_pin text,
  p_artist_id uuid,
  p_dato date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_check_pin(p_pin) then
    raise exception 'Feil PIN';
  end if;
  return public.member_conflicts_on_date(p_artist_id, p_dato);
end;
$$;

revoke all on function public.admin_member_conflicts_on_date(text, uuid, date) from public;
grant execute on function public.admin_member_conflicts_on_date(text, uuid, date) to anon, authenticated;

-- Kommende datoer der aktive bandets medlemmer er booket i et annet band.
create or replace function public.my_band_busy_notices()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_band uuid := public.current_band_id();
  v_artist uuid;
begin
  if auth.uid() is null then
    return '[]'::jsonb;
  end if;
  if v_band is null then
    return '[]'::jsonb;
  end if;

  select artist_id into v_artist from public.bands where id = v_band;
  if v_artist is null then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'member_id', c.member_id,
        'member_navn', c.member_navn,
        'member_rolle', c.member_rolle,
        'other_band_id', c.other_band_id,
        'other_band_navn', c.other_band_navn,
        'other_artist_id', c.other_artist_id,
        'other_artist_navn', c.other_artist_navn,
        'gig_id', c.gig_id,
        'dato', c.dato
      )
      order by c.dato, c.member_navn
    )
    from (
      select distinct
        m.id as member_id,
        coalesce(nullif(trim(m.navn), ''), 'Medlem') as member_navn,
        coalesce(nullif(trim(m.rolle), ''), 'Medlem') as member_rolle,
        ob.id as other_band_id,
        ob.navn as other_band_navn,
        oa.id as other_artist_id,
        oa.navn as other_artist_navn,
        g.id as gig_id,
        g.dato
      from public.band_members m
      join public.band_members om
        on om.user_id = m.user_id
       and om.band_id <> m.band_id
      join public.bands ob on ob.id = om.band_id
      join public.artists oa on oa.id = ob.artist_id
      join public.gigs g
        on g.artist_id = ob.artist_id
       and g.dato >= current_date
      where m.band_id = v_band
        and m.user_id is not null
        and ob.artist_id is distinct from v_artist
    ) c
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.my_band_busy_notices() from public;
grant execute on function public.my_band_busy_notices() to authenticated;

-- Inkluder konflikter i tilbud/forespørsler til artistportalen.
create or replace function public.my_offers()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.current_artist_id() is null then
    raise exception 'Logg inn på nytt';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'artist_id', o.artist_id,
        'dato', o.dato,
        'honorar', o.honorar,
        'spillested', o.spillested,
        'arrangor_navn', o.arrangor_navn,
        'melding', o.melding,
        'status', o.status,
        'avslag_kommentar', o.avslag_kommentar,
        'svarfrist', o.svarfrist,
        'booking_id', o.booking_id,
        'konflikter', public.member_conflicts_on_date(o.artist_id, o.dato)
      )
      order by case when o.status = 'pending' then 0 else 1 end, o.dato
    )
    from public.artist_offers o
    left join public.bookings b on b.id = o.booking_id
    where o.artist_id = public.current_artist_id()
      and o.status in ('pending', 'declined')
      and (o.booking_id is null or b.arkivert_at is null)
  ), '[]'::jsonb);
end;
$$;
