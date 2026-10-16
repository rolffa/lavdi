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
    $bio$EiGA er en duo som bookes til klubber, kulturhus og festivaler.

Sett lengde og rider avklares i forespørselen.$bio$,
    'assets/artist/eiga_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:75H5OcSeAZklaB7d3TdrMo',
    95000
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'Felgen Orkester',
    'Band',
    $bio$Felgen Orkester bookes til klubber, kulturhus og festivaler.

Sett lengde og rider avklares i forespørselen.$bio$,
    'assets/artist/felgen_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:5EscYV4Eedq37J5EKl7oaV',
    65000
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'Rolffa',
    'Band',
    $bio$Rolffa bookes til klubber, kulturhus og festivaler.

Sett lengde og rider avklares i forespørselen.$bio$,
    'assets/artist/rolffa_profile_1.jpg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:4Rdh0AevBwePcuPgt8fNeM',
    85000
  ),
  (
    'a1000000-0000-4000-8000-000000000003',
    'R & GM',
    'Duo',
    $bio$R & GM er en duo som bookes til klubber, kulturhus og festivaler.

Sett lengde og rider avklares i forespørselen.$bio$,
    'assets/artist/roggm_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:7F8ZcsMcpKLO4U7J4pqkpy',
    55000
  ),
  (
    'a1000000-0000-4000-8000-000000000007',
    'Kevin Boine',
    'Solo',
    $bio$Kevin Boine bookes til klubber, kulturhus og festivaler.

Sett lengde og rider avklares i forespørselen.$bio$,
    'assets/artist/kevin_profile_1.jpeg',
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
    'spotify:artist:7vjysb7HY9cLyDyHCMEtZu',
    75000
  ),
  (
    'a1000000-0000-4000-8000-000000000008',
    'Henning Anti',
    'Solo',
    $bio$Henning Anti bookes til klubber, kulturhus og festivaler.

Sett lengde og rider avklares i forespørselen.$bio$,
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

insert into public.bookings (
  id,
  artist_id,
  dato,
  status,
  arrangor_navn,
  organisasjon,
  kontaktperson,
  epost,
  telefon,
  spillested,
  notater
)
values (
  'c3000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  current_date + 21,
  'inquiry',
  'Bergensfestivalen',
  'Bergensfestivalen AS',
  'Nora Berg',
  'nora@example.com',
  '900 11 223',
  'Koengen, Bergen',
  ''
);

-- Bekreftelsen oppretter gigen med samme booking-ID og setter datoen til opptatt.
select public.confirm_booking('c3000000-0000-4000-8000-000000000001');

update public.gigs
set booking_token = 'amundsen-demo-linn',
    produksjon = jsonb_build_object(
      'arrangementsnavn', 'Koengen',
      'overnatting_navn', 'Hotel Norge',
      'overnatting_adresse', 'Nedre Ole Bulls plass 4, Bergen',
      'flyplass', 'Bergen lufthavn, Flesland',
      'avstand', '20 minutter med taxi',
      'reiserute', 'Fly til BGO, taxi 20 minutter til hotellet.',
      'get_in', '14:00',
      'lydprove', '16:00',
      'get_in_show', '18:30',
      'middag', '17:00',
      'showstart', '21:00',
      'curfew', '23:00',
      'load_out', '23:30',
      'middag_pa_overnatting', true,
      'middag_sted', '',
      'middag_adresse', '',
      'tekniker_navn', 'Mats Hauge',
      'tekniker_telefon', '900 33 441',
      'merknader', ''
    )
where booking_id = 'c3000000-0000-4000-8000-000000000001';

insert into public.availability (artist_id, dato, er_tilgjengelig)
values ('a1000000-0000-4000-8000-000000000001', current_date - 1, true)
on conflict (artist_id, dato) do update set er_tilgjengelig = true;

insert into public.bookings (
  id, artist_id, dato, status, arrangor_navn, organisasjon, kontaktperson, epost, telefon, spillested, notater
)
values (
  'c3000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  current_date - 1,
  'inquiry',
  'USF Verftet',
  'USF Verftet',
  'Ida Solheim',
  'ida@example.com',
  '900 22 110',
  'USF Verftet, Bergen',
  ''
);

select public.confirm_booking('c3000000-0000-4000-8000-000000000002');

update public.gigs
set produksjon = jsonb_build_object(
      'arrangementsnavn', 'Kvelden på USF',
      'overnatting_navn', 'Hotel Norge',
      'overnatting_adresse', 'Nedre Ole Bulls plass 4, Bergen',
      'flyplass', 'Bergen lufthavn, Flesland',
      'avstand', '20 minutter med taxi',
      'reiserute', 'Fly til BGO, taxi 20 minutter til hotellet.',
      'get_in', '15:00',
      'lydprove', '16:30',
      'get_in_show', '18:00',
      'middag', '17:30',
      'showstart', '21:00',
      'curfew', '23:00',
      'load_out', '23:30',
      'middag_pa_overnatting', false,
      'middag_sted', 'Colonialen',
      'middag_adresse', 'Kong Oscars gate 44, Bergen',
      'tekniker_navn', 'Mats Hauge',
      'tekniker_telefon', '900 33 441',
      'merknader', ''
    ),
    status = 'ready'
where booking_id = 'c3000000-0000-4000-8000-000000000002';

insert into public.repertoire (artist_id, tittel, spilletid)
values
  ('a1000000-0000-4000-8000-000000000001', 'Nordavind', '03:45'),
  ('a1000000-0000-4000-8000-000000000001', 'Etter midnatt', '04:12'),
  ('a1000000-0000-4000-8000-000000000001', 'Koengens lys', '03:20');

insert into public.bands (
  id, artist_id, navn, kontaktinfo, tech_felles, hospitality_felles,
  input_liste, monitor, scenerigg, pa_krav
)
values (
  'b4000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Rolffa',
  'rolffa@lavdi.no · 900 10 010',
  '2 vokal, gitar og keys. Stereomix til IEM. 4 linjer DI.',
  'Stille backstage med vann, kaffe og et rom til omkledning. 2 enkeltrom.',
  'Vokal 1, vokal 2, gitar og keys. 4 linjer DI.',
  'Stereomix til IEM for begge. Ingen wedges.',
  'Ingen DJ. Keys og gitar på scenen.',
  'Stereo PA med headroom til vokal.'
);

insert into public.band_members (id, band_id, navn, rolle, telefon, mat, tech_personlig, er_leder)
values
  (
    'b5000000-0000-4000-8000-000000000001',
    'b4000000-0000-4000-8000-000000000001',
    'Rolffa',
    'Bandleder',
    '900 10 010',
    'Vegetar. Ingen nøtter.',
    'IEM, Shure PSM 300. Egen pack.',
    true
  ),
  (
    'b5000000-0000-4000-8000-000000000002',
    'b4000000-0000-4000-8000-000000000001',
    'Sigrid Holm',
    'Musiker',
    '900 20 020',
    'Glutenfri.',
    'Trådløs gitar, egen sender.',
    false
  );

insert into public.band_invites (id, band_id, email, rolle, token)
values (
  'b6000000-0000-4000-8000-000000000001',
  'b4000000-0000-4000-8000-000000000001',
  'lyd@lavdi.no',
  'Lydtekniker',
  'demo-lyd'
);

commit;
