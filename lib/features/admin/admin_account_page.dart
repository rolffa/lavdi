import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../account/account_widgets.dart';
import '../shell/portal_scaffold.dart';
import 'admin_login.dart';

class AdminAccountPage extends StatefulWidget {
  const AdminAccountPage({super.key});

  @override
  State<AdminAccountPage> createState() => _AdminAccountPageState();
}

class _AdminAccountPageState extends State<AdminAccountPage> {
  var _loading = false;
  Object? _error;
  String? _avatarUrl;
  final _resetEmail = TextEditingController();
  var _avatarBusy = false;
  var _resetBusy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PortalScope.of(context).repository.isAdminSignedIn) _load();
    });
  }

  @override
  void dispose() {
    _resetEmail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      final avatar = await repository.fetchAdminAvatarUrl();
      if (!mounted) return;
      setState(() {
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
      final url = await repository.uploadAdminAvatar(
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

  Future<void> _sendReset() async {
    setState(() {
      _resetBusy = true;
      _status = null;
    });
    try {
      await PortalScope.of(context)
          .repository
          .adminSendPasswordReset(_resetEmail.text);
      if (!mounted) return;
      setState(() {
        _resetBusy = false;
        _status = 'Engangskode / nullstillingslenke er sendt.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resetBusy = false;
        _status = readableError(error);
      });
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
            maxWidth: 860,
            child: Column(
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
                  'Innstillinger for adminkonto. Invitasjoner til bandmedlemmer '
                  'finner du under Artister.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onImage,
                  ),
                ),
                const SizedBox(height: 20),
                if (!signedIn)
                  AdminLogin(onSignedIn: _load)
                else if (_loading)
                  const CenteredStatus(child: CircularProgressIndicator())
                else if (_error != null)
                  ErrorRetry(
                    message: readableError(_error!),
                    onRetry: _load,
                  )
                else ...[
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
                    title: 'Adminkonto',
                    subtitle: () {
                      final repo = PortalScope.of(context).repository;
                      final email = repo.adminAuthEmail;
                      if (email.isEmpty) {
                        return 'Bruker: ${repo.adminUsername}';
                      }
                      return 'Bruker: ${repo.adminUsername} · $email';
                    }(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarUploadRow(
                          imageUrl: _avatarUrl,
                          busy: _avatarBusy,
                          onPick: _uploadAvatar,
                        ),
                        const SizedBox(height: 20),
                        PasswordChangeForm(
                          onSubmit: ({
                            required currentPassword,
                            required newPassword,
                          }) {
                            return PortalScope.of(context)
                                .repository
                                .changeAdminPassword(
                                  currentPassword: currentPassword,
                                  newPassword: newPassword,
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AccountSection(
                    title: 'Artistkonto',
                    subtitle:
                        'Send engangskode ved glemt passord. '
                        'Invitasjoner sendes fra Artister.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _resetEmail,
                          keyboardType: TextInputType.emailAddress,
                          style: portalFieldStyle,
                          cursorColor: AppColors.ink,
                          decoration: fieldDecoration(
                            label: 'E-post for engangskode',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _resetBusy ? null : _sendReset,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            side: const BorderSide(color: AppColors.ink),
                          ),
                          child: Text(
                            _resetBusy ? 'Sender…' : 'Send engangskode',
                          ),
                        ),
                      ],
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
