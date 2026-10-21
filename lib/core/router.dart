import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_account_page.dart';
import '../features/admin/admin_archive_page.dart';
import '../features/admin/admin_artists_page.dart';
import '../features/admin/admin_calendar_page.dart';
import '../features/admin/admin_desk_page.dart';
import '../features/admin/admin_offer_page.dart';
import '../features/artist_portal/artist_account_page.dart';
import '../features/artist/artist_page.dart';
import '../features/artist/public_press_page.dart';
import '../core/rider_text.dart';
import '../features/artist_portal/artist_calendar_page.dart';
import '../features/artist_portal/band_page.dart';
import '../features/artist_portal/booking_request_page.dart';
import '../features/artist_portal/gig_dashboard_page.dart';
import '../features/artist_portal/invite_page.dart';
import '../features/artist_portal/min_side_page.dart';
import '../features/artist_portal/press_kit_page.dart';
import '../features/artist_portal/profile_page.dart';
import '../features/artist_portal/repertoire_page.dart';
import '../features/artist_portal/setlist_hub_page.dart';
import '../features/artist_portal/setlist_page.dart';
import '../features/artists/artists_page.dart';
import '../features/organizer/organizer_forms.dart';
import '../features/production/production_page.dart';
import '../features/riders/rider_pages.dart';
import '../features/shell/portal_scaffold.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ArtistsPage(),
    ),
    GoRoute(
      path: '/artist/presse',
      builder: (context, state) => PressKitPage(
        key: ValueKey('presse-${state.uri.queryParameters['band'] ?? ''}'),
      ),
    ),
    GoRoute(
      path: '/artister/:slug/presse',
      builder: (context, state) => PublicPressPage(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/artist/foresporsler/:id',
      builder: (context, state) =>
          BookingRequestPage(requestId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/artist/gigs/:id/settliste',
      builder: (context, state) => SetlistPage(gigId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/artist/:id',
      builder: (context, state) => ArtistPage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/min-side',
      builder: (context, state) => MinSidePage(
        key: ValueKey('min-side-${state.uri.queryParameters['band'] ?? ''}'),
      ),
      routes: [
        GoRoute(
          path: 'repertoar',
          builder: (context, state) => RepertoirePage(
            key: ValueKey('repertoar-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'band',
          builder: (context, state) => BandPage(
            key: ValueKey('band-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'settliste',
          builder: (context, state) => SetlistHubPage(
            key: ValueKey('settliste-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'ridere',
          builder: (context, state) => ArtistRidersPage(
            key: ValueKey('ridere-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'kalender',
          builder: (context, state) => ArtistCalendarPage(
            key: ValueKey('kalender-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'profil',
          builder: (context, state) => ProfilePage(
            key: ValueKey('profil-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'konto',
          builder: (context, state) => ArtistAccountPage(
            key: ValueKey('konto-${state.uri.queryParameters['band'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: 'invitasjon/:token',
          builder: (context, state) => InvitePage(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: 'gig/:gigId',
          builder: (context, state) => GigDashboardPage(gigId: state.pathParameters['gigId']!),
          routes: [
            GoRoute(
              path: 'settliste',
              builder: (context, state) => SetlistPage(gigId: state.pathParameters['gigId']!),
            ),
            GoRoute(
              path: 'hospitality',
              redirect: (context, state) => '/min-side/ridere',
            ),
            GoRoute(
              path: 'teknisk',
              redirect: (context, state) => '/min-side/ridere',
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDeskPage(),
    ),
    GoRoute(
      path: '/admin/arkiv',
      builder: (context, state) => const AdminArchivePage(),
    ),
    GoRoute(
      path: '/admin/artister',
      builder: (context, state) => const AdminArtistsPage(),
    ),
    GoRoute(
      path: '/admin/kalender',
      builder: (context, state) => const AdminCalendarPage(),
    ),
    GoRoute(
      path: '/admin/tilbud',
      builder: (context, state) => const AdminOfferPage(),
    ),
    GoRoute(
      path: '/admin/konto',
      builder: (context, state) => const AdminAccountPage(),
    ),
    GoRoute(
      path: '/arrangor/reise/:token',
      builder: (context, state) =>
          OrganizerTravelPage(token: state.pathParameters['token']!),
    ),
    GoRoute(
      path: '/arrangor/dag/:token',
      builder: (context, state) => OrganizerDayPage(token: state.pathParameters['token']!),
    ),
    GoRoute(
      path: '/production/:bookingToken',
      builder: (context, state) {
        return ProductionPage(bookingToken: state.pathParameters['bookingToken']!);
      },
      routes: [
        GoRoute(
          path: 'hospitality',
          builder: (context, state) => ProductionRiderPage(
            bookingToken: state.pathParameters['bookingToken']!,
            kind: RiderKind.hospitality,
          ),
        ),
        GoRoute(
          path: 'teknisk',
          builder: (context, state) => ProductionRiderPage(
            bookingToken: state.pathParameters['bookingToken']!,
            kind: RiderKind.technical,
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const NotFoundPage(),
);
