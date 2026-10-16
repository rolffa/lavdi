import '../models/artist.dart';

abstract final class DemoCatalog {
  static const productionToken = 'amundsen-demo-linn';
  static const productionBookingId = 'c3000000-0000-4000-8000-000000000001';
  static const adminUsername = 'admin';
  static const adminPassword = 'lavdi';
  static const artistEmail = 'rolffa@lavdi.no';
  static const artistPassword = 'lavdi';

  static const linnId = 'a1000000-0000-4000-8000-000000000001';
  static const harborId = 'a1000000-0000-4000-8000-000000000002';
  static const miraId = 'a1000000-0000-4000-8000-000000000003';
  static const fjordId = 'a1000000-0000-4000-8000-000000000004';
  static const kevinId = 'a1000000-0000-4000-8000-000000000007';
  static const henningId = 'a1000000-0000-4000-8000-000000000008';

  static const artists = <Artist>[
    Artist(
      id: fjordId,
      name: 'EiGA',
      tagline: 'Duo',
      bio:
          'EiGA er en duo som bookes til klubber, kulturhus og festivaler.\n\nSett lengde og rider avklares i forespørselen.',
      imageUrl: 'assets/artist/eiga_profile_1.jpeg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:75H5OcSeAZklaB7d3TdrMo',
      minPrice: 95000,
    ),
    Artist(
      id: harborId,
      name: 'Felgen Orkester',
      tagline: 'Band',
      bio:
          'Felgen Orkester bookes til klubber, kulturhus og festivaler.\n\nSett lengde og rider avklares i forespørselen.',
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
      bio:
          'Rolffa bookes til klubber, kulturhus og festivaler.\n\nSett lengde og rider avklares i forespørselen.',
      imageUrl: 'assets/artist/rolffa_profile_1.jpg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:4Rdh0AevBwePcuPgt8fNeM',
      minPrice: 85000,
    ),
    Artist(
      id: miraId,
      name: 'R & GM',
      tagline: 'Duo',
      bio:
          'R & GM er en duo som bookes til klubber, kulturhus og festivaler.\n\nSett lengde og rider avklares i forespørselen.',
      imageUrl: 'assets/artist/roggm_profile_1.jpeg',
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
          'Kevin Boine bookes til klubber, kulturhus og festivaler.\n\nSett lengde og rider avklares i forespørselen.',
      imageUrl: 'assets/artist/kevin_profile_1.jpeg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:7vjysb7HY9cLyDyHCMEtZu',
      minPrice: 75000,
    ),
    Artist(
      id: henningId,
      name: 'Henning Anti',
      tagline: 'Solo',
      bio:
          'Henning Anti bookes til klubber, kulturhus og festivaler.\n\nSett lengde og rider avklares i forespørselen.',
      imageUrl: 'assets/artist/henning_profile_1.jpeg',
      videoUrl:
          'https://videos.pexels.com/video-files/2022395/2022395-hd_1280_720_30fps.mp4',
      spotifyUri: 'spotify:artist:35itiet1xmfwdO1OhD3kER',
      minPrice: 75000,
    ),
  ];
}
