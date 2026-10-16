import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist.dart';
import '../shell/portal_scaffold.dart';
import 'admin_login.dart';

class AdminArtistsPage extends StatefulWidget {
  const AdminArtistsPage({super.key});

  @override
  State<AdminArtistsPage> createState() => _AdminArtistsPageState();
}

class _AdminArtistsPageState extends State<AdminArtistsPage> {
  var _loading = false;
  Object? _error;
  List<Artist> _artists = const [];
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PortalScope.of(context).repository.isAdminSignedIn) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final artists = await PortalScope.of(context).repository.fetchAdminArtists();
      artists.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _artists = artists;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _toggle(Artist artist, bool published) async {
    if (_saving.contains(artist.id)) return;
    setState(() {
      _saving.add(artist.id);
      _artists = [
        for (final item in _artists)
          if (item.id == artist.id) item.copyWith(published: published) else item,
      ];
      _error = null;
    });
    try {
      await PortalScope.of(context).repository.setArtistPublished(
        artistId: artist.id,
        published: published,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _artists = [
          for (final item in _artists)
            if (item.id == artist.id)
              item.copyWith(published: artist.published)
            else
              item,
        ];
        _error = error;
      });
    } finally {
      if (mounted) setState(() => _saving.remove(artist.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = PortalScope.of(context).repository.isAdminSignedIn;
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Artister',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.onImage,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Skjul en artistside for å ta den bort fra forsiden og direkte lenker. Publiser den igjen når den skal være synlig.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onImage,
                  ),
                ),
                const SizedBox(height: 20),
                if (!signedIn)
                  AdminLogin(onSignedIn: _load)
                else if (_loading)
                  const CenteredStatus(child: CircularProgressIndicator())
                else if (_error != null && _artists.isEmpty)
                  ErrorRetry(
                    message: readableError(_error!),
                    onRetry: _load,
                  )
                else ...[
                  if (_error != null) ...[
                    Text(
                      readableError(_error!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.busy,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.line),
                      ),
                    ),
                    child: InkSurface(
                      child: Column(
                        children: [
                          for (var i = 0; i < _artists.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, color: AppColors.line),
                            _ArtistPublishRow(
                              artist: _artists[i],
                              busy: _saving.contains(_artists[i].id),
                              onChanged: (value) => _toggle(_artists[i], value),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistPublishRow extends StatelessWidget {
  const _ArtistPublishRow({
    required this.artist,
    required this.busy,
    required this.onChanged,
  });

  final Artist artist;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artist.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  artist.published ? 'Synlig på forsiden' : 'Skjult',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: artist.published,
              onChanged: onChanged,
              activeThumbColor: AppColors.ink,
            ),
        ],
      ),
    );
  }
}
