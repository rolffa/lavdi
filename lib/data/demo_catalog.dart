import '../models/artist.dart';

abstract final class DemoCatalog {
  static const productionToken = 'amundsen-demo-linn';
  static const productionBookingId = 'c3000000-0000-4000-8000-000000000001';
  static const adminUsername = 'admin';
  static const adminEmail = 'admin@lavdi.no';
  static const adminPassword = 'lavdi';
  static const artistEmail = 'rolffa@lavdi.no';
  static const artistPassword = 'lavdi';

  static const linnId = 'a1000000-0000-4000-8000-000000000001';
  static const harborId = 'a1000000-0000-4000-8000-000000000002';
  static const miraId = 'a1000000-0000-4000-8000-000000000003';
  static const fjordId = 'a1000000-0000-4000-8000-000000000004';
  static const kevinId = 'a1000000-0000-4000-8000-000000000007';
  static const henningId = 'a1000000-0000-4000-8000-000000000008';

  /// Fra [content/bios/eiga.txt] (konvertert fra eiga.rtf).
  static const eigaBio =
      'EiGA er en samisk joike- og elektronika-duo som springer ut fra Máze i Sápmi. Duoen består av joikerne og artistene Johan Ivvar Gaup og Piera Eira. Sistnevnte vant sangdelen i Sámi Grand Prix i 2025 sammen med MÁIJÁ med låten «Dálkkiid Čađa».\n\n'
      'EiGA er kjent for å forene tradisjonell joik med moderne EDM- og elektronika-elementer, noe som skaper et unikt og energisk lydbilde som har fått stor oppmerksomhet på festivaler og arrangementer. Duoen har gitt ut utgivelser som låten «Duinna» (gjestet av Elin Oskal) og singelen «Muittašan» (gjestet av MÁIJÁ).\n\n'
      'Eiga passer like godt til klubbscener som til store festivaler.';

  static const artists = <Artist>[
    Artist(
      id: fjordId,
      name: 'EiGA',
      tagline: 'Duo',
      bio: eigaBio,
      imageUrl: 'assets/artist/eiga_profile_2.jpeg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:75H5OcSeAZklaB7d3TdrMo',
      minPrice: 95000,
    ),
    Artist(
      id: harborId,
      name: 'Felgen Orkester',
      tagline: 'Band',
      bio: 'Felgen Orkester bookes til klubber, kulturhus og festivaler.',
      imageUrl: 'assets/artist/felgen_profile_1.jpeg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:5EscYV4Eedq37J5EKl7oaV',
      minPrice: 65000,
    ),
    Artist(
      id: linnId,
      name: 'Rolffa',
      tagline: 'Band',
      bio: 'Rolffa bookes til klubber, kulturhus og festivaler.',
      imageUrl: 'assets/artist/rolffa_profile_1.jpg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:4Rdh0AevBwePcuPgt8fNeM',
      minPrice: 85000,
    ),
    Artist(
      id: miraId,
      name: 'Avskilta',
      tagline: 'Duo',
      bio:
          'Først het de Rolffa feat. GM. Så kuttet de inn til beinet og ble R & GM. '
          'Nå har de mistet bokstavene helt og blitt Avskilta. '
          'Navneendringene skyldes ikke identitetskrise, men ren slitasje etter litt for mange mil på veien '
          'og litt for høy stemning i lokalet. '
          'Skiltene er kanskje inndratt og EU-kontrollen for lengst utløpt, men motoren går bedre enn noen gang. '
          'Avskilta er perfekt når du vil ha en partyduo uten bremser, med fullt trøkk og null skam på dansegulvet.',
      imageUrl: 'assets/artist/Avskilta_full_rust.jpg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:7F8ZcsMcpKLO4U7J4pqkpy',
      minPrice: 55000,
    ),
    Artist(
      id: kevinId,
      name: 'Kevin Boine',
      tagline: 'Solo',
      bio:
          'Med over 200 millioner streams, har Kevin Boine vokst seg til å bli en av Nord-Norges yndlinger. '
          'Den 32 år gamle artisten fra Tana har opparbeidet seg en lojal og stadig voksende fanskare, '
          'og spiller festivaler over hele Skandinavia. '
          'Som en av svært få i sin sjanger krysser han landegrenser og forener folk med '
          'sin fengende og folkelige stil.',
      imageUrl: 'assets/artist/kevin_profile_2.JPG',
      videoUrl: 'assets/artist/movie/kevin_movie_1.mp4',
      spotifyUri: 'spotify:artist:7vjysb7HY9cLyDyHCMEtZu',
      minPrice: 75000,
    ),
    Artist(
      id: henningId,
      name: 'Henning Anti',
      tagline: 'Solo',
      bio: 'Henning Anti bookes til klubber, kulturhus og festivaler.',
      imageUrl: 'assets/artist/henning_profile_1.jpeg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:35itiet1xmfwdO1OhD3kER',
      minPrice: 75000,
    ),
  ];
}
