import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/spotify.dart';
import '../../core/theme.dart';
import '../../core/zip_store.dart';
import '../../models/press_kit.dart';
import '../../web/external_link.dart';
import '../../web/rider_files.dart';
import '../shell/portal_scaffold.dart';

class PublicPressPage extends StatefulWidget {
  const PublicPressPage({super.key, required this.slug});

  final String slug;

  @override
  State<PublicPressPage> createState() => _PublicPressPageState();
}

class _PublicPressPageState extends State<PublicPressPage> {
  PressKit? _kit;
  Object? _error;
  var _loading = true;
  var _missing = false;
  var _downloading = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _missing = false;
    });
    try {
      final kit = await PortalScope.of(context).repository
          .fetchPublicPressKit(widget.slug);
      if (!mounted) return;
      setState(() {
        _kit = kit;
        _missing = kit == null;
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

  Future<void> _copyBio(String bio) async {
    await Clipboard.setData(ClipboardData(text: bio));
    if (!mounted) return;
    setState(() => _notice = 'Bio er kopiert.');
  }

  Future<void> _downloadOne(PressPhoto photo) async {
    setState(() => _notice = null);
    try {
      final bytes = await PortalScope.of(context).repository
          .downloadPressPhoto(photo);
      saveBytes(bytes, photo.filename, photo.contentType);
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = readableError(error));
    }
  }

  Future<void> _downloadAll(PressKit kit) async {
    setState(() {
      _downloading = true;
      _notice = null;
    });
    try {
      final entries = <ZipEntry>[];
      for (final photo in kit.filled) {
        final bytes = await PortalScope.of(context).repository
            .downloadPressPhoto(photo);
        entries.add(ZipEntry(name: photo.filename, bytes: bytes));
      }
      saveBytes(
        storeZip(entries),
        '${kit.slug}-pressebilder.zip',
        'application/zip',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = readableError(error));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kit = _kit;
    return PortalScaffold(
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                PageFrame(
                  maxWidth: 760,
                  child: _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : _missing || kit == null
                      ? Text(
                          'Fant ikke pressepakken.',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.onImage,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kit.artistName,
                              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pressepakke',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              kit.bio.trim().isEmpty
                                  ? 'Ingen bio er lagt ut ennå.'
                                  : kit.bio.trim(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            if (kit.bio.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => _copyBio(kit.bio.trim()),
                                child: const Text('Kopier bio'),
                              ),
                            ],
                            const SizedBox(height: 28),
                            Text(
                              'Musikk',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MusicLink(uri: kit.spotifyUri),
                            if (kit.filled.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              Text(
                                'Pressebilder',
                                style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.onImage,
                              ),
                              ),
                              const SizedBox(height: 12),
                              for (final photo in kit.filled) ...[
                                _PublicPhoto(
                                  photo: photo,
                                  onDownload: () => _downloadOne(photo),
                                ),
                                const SizedBox(height: 16),
                              ],
                              FilledButton(
                                onPressed: _downloading
                                    ? null
                                    : () => _downloadAll(kit),
                                child: const Text('Last ned alle'),
                              ),
                            ],
                            if (_notice != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _notice!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onImage,
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

class _MusicLink extends StatelessWidget {
  const _MusicLink({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = spotifyWebUrl(uri);
    if (url == null) {
      return Text(
        'Ingen musikklenke er lagt inn.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: AppColors.onImageMuted,
        ),
      );
    }
    return TextButton(
      onPressed: () => openExternal(url),
      child: const Text('Åpne på Spotify'),
    );
  }
}

class _PublicPhoto extends StatelessWidget {
  const _PublicPhoto({required this.photo, required this.onDownload});

  final PressPhoto photo;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: photo.bytes != null
              ? Image.memory(photo.bytes!, fit: BoxFit.cover)
              : Image.network(photo.publicUrl, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onDownload,
          child: const Text('Last ned original (høy oppløsning)'),
        ),
      ],
    );
  }
}
