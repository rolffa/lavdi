-- Eksempelroster. EiGA, Felgen Orkester, Rolffa, R & GM, Kevin Boine og Henning Anti har egne Spotify-profiler.
-- Videolenkene er arkivklipp. Bytt video_url til artistens eget liveshow på omtrent 30 sekunder.
-- Produksjonslenken i demomodus og her bruker token amundsen-demo-linn.
-- Slett den før lansering.

begin;

delete from public.band_invites
where band_id in (
  select id from public.bands where artist_id in (
    'a1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000005',
    'a1000000-0000-4000-8000-000000000006',
    'a1000000-0000-4000-8000-000000000007',
    'a1000000-0000-4000-8000-000000000008'
  )
);

delete from public.band_members
where band_id in (
  select id from public.bands where artist_id in (
    'a1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000005',
    'a1000000-0000-4000-8000-000000000006',
    'a1000000-0000-4000-8000-000000000007',
    'a1000000-0000-4000-8000-000000000008'
  )
);

delete from public.bands
where artist_id in (
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006',
  'a1000000-0000-4000-8000-000000000007',
  'a1000000-0000-4000-8000-000000000008'
);

delete from public.repertoire
where artist_id in (
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006',
  'a1000000-0000-4000-8000-000000000007',
  'a1000000-0000-4000-8000-000000000008'
);

delete from public.gigs
where artist_id in (
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006',
  'a1000000-0000-4000-8000-000000000007',
  'a1000000-0000-4000-8000-000000000008'
);

delete from public.bookings
where artist_id in (
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006',
  'a1000000-0000-4000-8000-000000000007',
  'a1000000-0000-4000-8000-000000000008'
);

delete from public.availability
where artist_id in (
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006',
  'a1000000-0000-4000-8000-000000000007',
  'a1000000-0000-4000-8000-000000000008'
);

delete from public.artists
where id in (
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000005',
  'a1000000-0000-4000-8000-000000000006',
  'a1000000-0000-4000-8000-000000000007',
  'a1000000-0000-4000-8000-000000000008'
);

insert into public.artists (id, navn, tagline, bio, bilde_url, video_url, spotify_uri, minstepris)
values
  (
    'a1000000-0000-4000-8000-000000000004',
    'EiGA',
    'Duo',
    $bio$EiGA er en samisk joike- og elektronika-duo som springer ut fra Máze i Sápmi. Duoen består av joikerne og artistene Johan Ivvar Gaup og Piera Eira. Sistnevnte vant sangdelen i Sámi Grand Prix i 2025 sammen med MÁIJÁ med låten «Dálkkiid Čađa».

EiGA er kjent for å forene tradisjonell joik med moderne EDM- og elektronika-elementer, noe som skaper et unikt og energisk lydbilde som har fått stor oppmerksomhet på festivaler og arrangementer. Duoen har gitt ut utgivelser som låten «Duinna» (gjestet av Elin Oskal) og singelen «Muittašan» (gjestet av MÁIJÁ).

Eiga passer like godt til klubbscener som til store festivaler.$bio$,
    'assets/artist/eiga_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:75H5OcSeAZklaB7d3TdrMo',
    95000
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'Felgen Orkester',
    'Band',
    $bio$Felgen Orkester bookes til klubber, kulturhus og festivaler.$bio$,
    'assets/artist/felgen_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:5EscYV4Eedq37J5EKl7oaV',
    65000
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'Rolffa',
    'Band',
    $bio$Rolffa bookes til klubber, kulturhus og festivaler.$bio$,
    'assets/artist/rolffa_profile_1.jpg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:4Rdh0AevBwePcuPgt8fNeM',
    85000
  ),
  (
    'a1000000-0000-4000-8000-000000000003',
    'Avskilta',
    'Duo',
    $bio$Avskilta er en duo som bookes til klubber, kulturhus og festivaler.$bio$,
    'assets/artist/Avskilta_full_rust.jpg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:7F8ZcsMcpKLO4U7J4pqkpy',
    55000
  ),
  (
    'a1000000-0000-4000-8000-000000000007',
    'Kevin Boine',
    'Solo',
    $bio$Med over 200 millioner streams, har Kevin Boine vokst seg til å bli en av Nord-Norges yndlinger. Den 32 år gamle artisten fra Tana har opparbeidet seg en lojal og stadig voksende fanskare, og spiller festivaler over hele Skandinavia. Som en av svært få i sin sjanger krysser han landegrenser og forener folk med sin fengende og folkelige stil.$bio$,
    'assets/artist/kevin_profile_2.JPG',
    'assets/artist/movie/kevin_movie_1.mp4',
    'spotify:artist:7vjysb7HY9cLyDyHCMEtZu',
    75000
  ),
  (
    'a1000000-0000-4000-8000-000000000008',
    'Henning Anti',
    'Solo',
    $bio$Henning Anti bookes til klubber, kulturhus og festivaler.$bio$,
    'assets/artist/henning_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:35itiet1xmfwdO1OhD3kER',
    75000
  );

-- Samme regel som exampleDateIsAvailable i lib/core/calendar_logic.dart.
insert into public.availability (artist_id, dato, er_tilgjengelig)
select
  a.id,
  (current_date + offs)::date,
  ((extract(day from current_date + offs)::int + extract(month from current_date + offs)::int + ascii(substr(a.navn, 1, 1))) % 5) <> 0
from public.artists a
cross join generate_series(0, 150) as offs;

update public.availability
set er_tilgjengelig = true
where artist_id = 'a1000000-0000-4000-8000-000000000001'
  and dato = current_date + 21;

-- Ingen demoforespørsler, demolåter, demomedlemmer eller demoridere.
-- Bandleder for Rolffa beholdes tom for profil/rider (fylles i portalen).

insert into public.bands (
  id, artist_id, navn, kontaktinfo, tech_felles, hospitality_felles,
  input_liste, monitor, scenerigg, pa_krav
)
values (
  'b4000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Rolffa',
  'rolffa@lavdi.no',
  '',
  '',
  '',
  '',
  '',
  ''
);

insert into public.band_members (id, band_id, navn, rolle, telefon, mat, tech_personlig, er_leder)
values (
  'b5000000-0000-4000-8000-000000000001',
  'b4000000-0000-4000-8000-000000000001',
  'Rolffa',
  'Bandleder',
  '',
  '',
  '',
  true
);

commit;
