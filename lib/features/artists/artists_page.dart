import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist.dart';
import '../shell/portal_scaffold.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  List<Artist>? _artists;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final artists = await repository.fetchArtists();
      if (!mounted) return;
      setState(() {
        _artists = artists;
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

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const CenteredStatus(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorRetry(message: readableError(_error!), onRetry: _load);
    }

    final artists = _artists ?? const <Artist>[];
    final theme = Theme.of(context);

    return ListView(
      children: [
        PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Artister', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
              const SizedBox(height: 10),
              Text(
                'Velg en artist for profil, tilgjengelighet og booking.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.onImageMuted,
                ),
              ),
              const SizedBox(height: 32),
              if (artists.isEmpty)
                const Text('Ingen artister er lagt inn ennå.')
              else
                _ArtistGrid(artists: artists),
              const SizedBox(height: 48),
              Text(
                Brand.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onImageMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtistGrid extends StatelessWidget {
  const _ArtistGrid({required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const gap = 22.0;
        final rows = <Widget>[];
        for (var index = 0; index < artists.length; index += columns) {
          final slice = artists.skip(index).take(columns).toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: gap),
                    Expanded(
                      child: column < slice.length
                          ? ArtistCard(artist: slice[column])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: InkWell(
        onTap: () => context.push('/artist/${artist.id}'),
        child: InkSurface(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArtistPhoto(artist: artist),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                    const SizedBox(height: 4),
                    Text(
                      artist.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class ArtistPhoto extends StatelessWidget {
  const ArtistPhoto({
    super.key,
    required this.artist,
    this.aspectRatio = 4 / 3,
  });

  final Artist artist;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final alignment = artist.imageUrl.endsWith('roggm_profile_1.jpeg')
        ? Alignment.topCenter
        : Alignment.center;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: artist.imageUrl.startsWith('assets/')
          ? Image.asset(
              artist.imageUrl,
              fit: BoxFit.cover,
              alignment: alignment,
              semanticLabel: artist.name,
              errorBuilder: (context, error, stackTrace) =>
                  _PhotoFallback(name: artist.name),
            )
          : Image.network(
              artist.imageUrl,
              fit: BoxFit.cover,
              alignment: alignment,
              semanticLabel: artist.name,
              errorBuilder: (context, error, stackTrace) =>
                  _PhotoFallback(name: artist.name),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(color: AppColors.paperDeep);
              },
            ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name[0];
    return ColoredBox(
      color: AppColors.hero,
      child: Center(
        child: Text(
          letter,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
