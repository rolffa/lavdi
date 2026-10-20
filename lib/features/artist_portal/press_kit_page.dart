import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/press_kit.dart';
import '../../web/press_files.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class PressKitPage extends StatefulWidget {
  const PressKitPage({super.key});

  @override
  State<PressKitPage> createState() => _PressKitPageState();
}

class _PressKitPageState extends State<PressKitPage> {
  final _bio = TextEditingController();
  PressKit? _kit;
  Object? _error;
  var _loading = true;
  var _signedOut = false;
  var _savingBio = false;
  int? _uploadingSlot;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      final session = await repository.currentArtist();
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _kit = null;
          _signedOut = true;
          _loading = false;
        });
        return;
      }
      final kit = await repository.fetchMyPressKit();
      if (!mounted) return;
      _bio.text = kit?.bio ?? '';
      setState(() {
        _kit = kit;
        _signedOut = false;
        _error = kit == null
            ? PortalException('Kunne ikke laste pressepakken.')
            : null;
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

  Future<void> _saveBio() async {
    setState(() {
      _savingBio = true;
      _message = null;
    });
    try {
      final kit = await PortalScope.of(context).repository
          .savePressBio(_bio.text);
      if (!mounted) return;
      setState(() {
        _kit = kit;
        _message = 'Bio er lagret.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = readableError(error));
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  Future<void> _replacePhoto(int slot) async {
    final picked = await pickPressPhoto();
    if (picked == null || !mounted) return;
    setState(() {
      _uploadingSlot = slot;
      _message = null;
    });
    try {
      final kit = await PortalScope.of(context).repository.savePressPhoto(
        slot: slot,
        filename: picked.name,
        bytes: picked.bytes,
      );
      if (!mounted) return;
      setState(() {
        _kit = kit;
        _message = 'Pressebilde $slot er oppdatert.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = readableError(error));
    } finally {
      if (mounted) setState(() => _uploadingSlot = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kit = _kit;
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                ArtistFrame(
                  child: _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : _signedOut
                      ? const Text(
                          'Logg inn på Min side for å redigere pressepakken.',
                        )
                      : kit == null
                      ? ErrorRetry(
                          message: 'Kunne ikke laste pressepakken.',
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pressepakke',
                              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Offisiell bio og tre pressebilder. Musikklenken hentes fra artistprofilen.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            InkSurface(
                              child: TextField(
                                controller: _bio,
                                minLines: 6,
                                maxLines: 14,
                                style: portalFieldStyle,
                                cursorColor: AppColors.ink,
                                decoration: fieldDecoration(
                                  label: 'Skriv den offisielle biografien',
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _savingBio ? null : _saveBio,
                              child: const Text('Lagre bio'),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Pressebilder',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (var slot = 1; slot <= 3; slot++) ...[
                              _PhotoSlot(
                                slot: slot,
                                photo: kit.photo(slot),
                                busy: _uploadingSlot == slot,
                                onReplace: _uploadingSlot == null
                                    ? () => _replacePhoto(slot)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_message != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _message!,
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

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.slot,
    required this.photo,
    required this.busy,
    required this.onReplace,
  });

  final int slot;
  final PressPhoto? photo;
  final bool busy;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: InkSurface(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pressebilde $slot',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (photo != null)
              ClipRect(
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _PressImage(photo: photo!),
                ),
              )
            else
              Text(
                'Ingen bilde lastet opp.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy ? null : onReplace,
              child: Text(photo == null ? 'Last opp' : 'Bytt bilde'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PressImage extends StatelessWidget {
  const _PressImage({required this.photo});

  final PressPhoto photo;

  @override
  Widget build(BuildContext context) {
    if (photo.bytes != null) {
      return Image.memory(photo.bytes!, fit: BoxFit.cover);
    }
    if (photo.publicUrl.isNotEmpty) {
      return Image.network(photo.publicUrl, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }
}
