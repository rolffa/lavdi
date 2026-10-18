import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist_session.dart';
import '../account/account_widgets.dart';
import '../shell/portal_scaffold.dart';

class ArtistAccountPage extends StatefulWidget {
  const ArtistAccountPage({super.key});

  @override
  State<ArtistAccountPage> createState() => _ArtistAccountPageState();
}

class _ArtistAccountPageState extends State<ArtistAccountPage> {
  ArtistSession? _session;
  String? _avatarUrl;
  var _loading = true;
  var _avatarBusy = false;
  Object? _error;
  String? _status;

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
    });
    try {
      final repository = PortalScope.of(context).repository;
      final session = await repository.currentArtist();
      if (session == null) {
        if (!mounted) return;
        context.go('/min-side');
        return;
      }
      final avatar = await repository.fetchMyAvatarUrl();
      if (!mounted) return;
      setState(() {
        _session = session;
        _avatarUrl = avatar;
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

  Future<void> _uploadAvatar() async {
    final repository = PortalScope.of(context).repository;
    final picked = await pickAccountPhoto();
    if (picked == null) return;
    setState(() {
      _avatarBusy = true;
      _status = null;
    });
    try {
      final url = await repository.uploadMyAvatar(
        filename: picked.name,
        bytes: Uint8List.fromList(picked.bytes),
      );
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _avatarBusy = false;
        _status = 'Profilbildet er lagret.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarBusy = false;
        _status = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                PageFrame(
                  maxWidth: 720,
                  child: _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Konto',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              session == null
                                  ? ''
                                  : '${session.artistName} · ${session.email}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_status != null) ...[
                              Text(
                                _status!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onImage,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            AccountSection(
                              title: 'Profil',
                              child: AvatarUploadRow(
                                imageUrl: _avatarUrl,
                                busy: _avatarBusy,
                                onPick: _uploadAvatar,
                              ),
                            ),
                            const SizedBox(height: 20),
                            AccountSection(
                              title: 'Passord',
                              child: PasswordChangeForm(
                                onSubmit: ({
                                  required currentPassword,
                                  required newPassword,
                                }) {
                                  return PortalScope.of(context)
                                      .repository
                                      .changeArtistPassword(
                                        currentPassword: currentPassword,
                                        newPassword: newPassword,
                                      );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
