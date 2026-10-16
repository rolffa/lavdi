-- Teknisk rider, scenekart og PDF-eksport.
-- Trygt å kjøre på nytt etter schema.sql.

alter table public.bands
  add column if not exists input_liste text not null default '',
  add column if not exists monitor text not null default '',
  add column if not exists scenerigg text not null default '',
  add column if not exists pa_krav text not null default '',
  add column if not exists stage_plot_path text,
  add column if not exists stage_plot_name text,
  add column if not exists stage_plot_type text;

comment on column public.bands.input_liste is 'Inputliste og patch på den tekniske rideren.';
comment on column public.bands.monitor is 'Wedges og IEM for hele bandet.';
comment on column public.bands.scenerigg is 'DJ- og scenerigg.';
comment on column public.bands.pa_krav is 'Krav til PA.';
comment on column public.bands.stage_plot_path is 'Sti i bucket stage-plots. Tom når intet kart er lastet opp.';
comment on column public.bands.stage_plot_name is 'Opprinnelig filnavn på scenekartet.';
comment on column public.bands.stage_plot_type is 'MIME-type: image/png, image/jpeg, image/svg+xml eller application/pdf.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'stage-plots',
  'stage-plots',
  false,
  8388608,
  array['image/png', 'image/jpeg', 'image/svg+xml', 'application/pdf']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists stage_plots_member_read on storage.objects;
create policy stage_plots_member_read on storage.objects
for select to authenticated
using (
  bucket_id = 'stage-plots'
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_insert on storage.objects;
create policy stage_plots_leader_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'stage-plots'
  and public.is_band_leader()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_update on storage.objects;
create policy stage_plots_leader_update on storage.objects
for update to authenticated
using (
  bucket_id = 'stage-plots'
  and public.is_band_leader()
  and (storage.foldername(name))[1] = public.current_band_id()::text
)
with check (
  bucket_id = 'stage-plots'
  and public.is_band_leader()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

drop policy if exists stage_plots_leader_delete on storage.objects;
create policy stage_plots_leader_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'stage-plots'
  and public.is_band_leader()
  and (storage.foldername(name))[1] = public.current_band_id()::text
);

create or replace function public.riders_for_token(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', b.id,
    'artist_id', b.artist_id,
    'navn', b.navn,
    'kontaktinfo', b.kontaktinfo,
    'tech_felles', b.tech_felles,
    'hospitality_felles', b.hospitality_felles,
    'input_liste', b.input_liste,
    'monitor', b.monitor,
    'scenerigg', b.scenerigg,
    'pa_krav', b.pa_krav,
    'stage_plot_name', b.stage_plot_name,
    'stage_plot_type', b.stage_plot_type,
    'medlemmer', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'band_id', m.band_id,
          'navn', m.navn,
          'rolle', m.rolle,
          'telefon', m.telefon,
          'mat', m.mat,
          'tech_personlig', m.tech_personlig,
          'er_leder', m.er_leder
        )
        order by m.er_leder desc, m.navn
      )
      from public.band_members m
      where m.band_id = b.id
    ), '[]'::jsonb)
  )
  from public.gigs g
  join public.bands b on b.artist_id = g.artist_id
  where g.booking_token = p_token;
$$;

revoke all on function public.riders_for_token(text) from public;
grant execute on function public.riders_for_token(text) to anon, authenticated;
