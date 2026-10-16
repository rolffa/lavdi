import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/calendar_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/artist_slug.dart';
import '../../core/spotify.dart';
import '../../core/theme.dart';
import '../../models/artist.dart';
import '../../web/embeds.dart';
import '../shell/portal_scaffold.dart';
import 'availability_calendar.dart';
import 'booking_dialog.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.id});

  final String id;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  Artist? _artist;
  Map<DateTime, bool> _availability = {};
  late DateTime _month;
  DateTime? _selected;
  Object? _error;
  var _loading = true;
  var _monthLoading = false;
  var _missing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
      _missing = false;
    });
    try {
      final artist = await repository.fetchArtist(widget.id);
      if (!mounted) return;
      if (artist == null) {
        setState(() {
          _artist = null;
          _missing = true;
          _loading = false;
        });
        return;
      }
      final days = await _fetchMonth(artist.id, _month);
      if (!mounted) return;
      setState(() {
        _artist = artist;
        _availability = days;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<Map<DateTime, bool>> _fetchMonth(String artistId, DateTime month) {
    final repository = PortalScope.of(context).repository;
    return repository
        .fetchAvailability(
          artistId: artistId,
          from: DateTime(month.year, month.month, 1),
          to: DateTime(month.year, month.month + 1, 0),
        )
        .then(
          (days) => {
            for (final day in days) dateOnly(day.date): day.isAvailable,
          },
        );
  }

  Future<void> _changeMonth(int delta) async {
    final artist = _artist;
    if (artist == null) return;
    final today = DateTime.now();
    if (!canMoveMonth(from: _month, delta: delta, today: today)) return;
    final next = DateTime(_month.year, _month.month + delta, 1);
    setState(() {
      _month = next;
      _monthLoading = true;
    });
    try {
      final days = await _fetchMonth(artist.id, next);
      if (!mounted) return;
      setState(() {
        _availability = days;
        _monthLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _month = DateTime(_month.year, _month.month - delta, 1);
        _monthLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(readableError(error))));
    }
  }

  Future<void> _openBooking(DateTime date) async {
    final artist = _artist;
    if (artist == null) return;
    setState(() => _selected = date);
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => BookingDialog(artist: artist, date: date),
    );
    if (!mounted || sent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forespørselen er sendt')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const CenteredStatus(child: CircularProgressIndicator());
    }
    if (_error != null && _artist == null) {
      return ErrorRetry(message: readableError(_error!), onRetry: _load);
    }
    if (_missing || _artist == null) {
      return PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fant ikke artisten',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Til artister'),
            ),
          ],
        ),
      );
    }

    return ListView(children: [PageFrame(child: _profile(context, _artist!))]);
  }

  Widget _profile(BuildContext context, Artist artist) {
    final theme = Theme.of(context);
    final embed = spotifyEmbedUrl(artist.spotifyUri);
    final paragraphs = artist.bio
        .split('\n\n')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Artister'),
        ),
        const SizedBox(height: 8),
        _VideoBanner(artist: artist),
        const SizedBox(height: 8),
        Text(
          'Liveshow · 30 sekunder',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          artist.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.onImage,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          artist.tagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        TextButton(
          onPressed: () =>
              context.go('/artister/${artistSlug(artist.name)}/presse'),
          child: const Text('Pressepakke'),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 900;
            final details = _details(
              theme: theme,
              paragraphs: paragraphs,
              embed: embed,
            );
            final calendar = AvailabilityCalendar(
              month: _month,
              today: DateTime.now(),
              availability: _availability,
              selected: _selected,
              loading: _monthLoading,
              onMonthChanged: _changeMonth,
              onDateSelected: _openBooking,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 28), calendar],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: details),
                const SizedBox(width: 28),
                Expanded(flex: 5, child: calendar),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _details({
    required ThemeData theme,
    required Iterable<String> paragraphs,
    required String? embed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Om artisten',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.onImage,
          ),
        ),
        const SizedBox(height: 12),
        for (final paragraph in paragraphs) ...[
          Text(
            paragraph,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        Text(
          'Spotify',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.onImage,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Topplåter',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (embed == null)
          const Text('Ingen Spotify-profil er lagt inn.')
        else
          SizedBox(
            height: 380,
            width: double.infinity,
            child: buildSpotifyEmbed(url: embed),
          ),
      ],
    );
  }
}

class _VideoBanner extends StatelessWidget {
  const _VideoBanner({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(constraints.maxWidth * 9 / 21, 340.0);
        return Semantics(
          label: 'Liveshow-klipp for ${artist.name}',
          child: ColoredBox(
            color: AppColors.hero,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: artist.videoUrl.isEmpty
                  ? const Center(
                      child: Text(
                        'Ingen videolenke er lagt inn',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : buildVideoEmbed(
                      url: artist.videoUrl,
                      poster: artist.imageUrl.startsWith('http')
                          ? artist.imageUrl
                          : '',
                    ),
            ),
          ),
        );
      },
    );
  }
}
