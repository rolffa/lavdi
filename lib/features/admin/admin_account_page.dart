import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist.dart';
import '../../models/band.dart';
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
  List<Artist> _artists = const [];
  String? _artistId;
  List<BandMember> _accounts = const [];
  final _inviteEmail = TextEditingController();
  final _inviteRole = TextEditingController(text: 'Musiker');
  final _resetEmail = TextEditingController();
  var _asLeader = false;
  var _avatarBusy = false;
  var _inviteBusy = false;
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
    _inviteEmail.dispose();
    _inviteRole.dispose();
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
      final artists = await repository.fetchAdminArtists();
      artists.sort((a, b) => a.name.compareTo(b.name));
      final avatar = await repository.fetchAdminAvatarUrl();
      final artistId = _artistId ?? (artists.isEmpty ? null : artists.first.id);
      final accounts = artistId == null
          ? const <BandMember>[]
          : await repository.fetchAdminBandAccounts(artistId);
      if (!mounted) return;
      setState(() {
        _artists = artists;
        _artistId = artistId;
        _accounts = accounts;
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

  Future<void> _selectArtist(String? artistId) async {
    if (artistId == null) return;
    setState(() {
      _artistId = artistId;
      _status = null;
    });
    try {
      final accounts =
          await PortalScope.of(context).repository.fetchAdminBandAccounts(artistId);
      if (!mounted) return;
      setState(() => _accounts = accounts);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = readableError(error));
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

  Future<void> _invite() async {
    final artistId = _artistId;
    if (artistId == null) return;
    setState(() {
      _inviteBusy = true;
      _status = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      final invite = await repository.adminInviteBandMember(
        artistId: artistId,
        email: _inviteEmail.text,
        role: _inviteRole.text,
        asLeader: _asLeader,
      );
      await repository.sendInviteEmail(invite.token);
      final origin = Uri.base.origin;
      await Clipboard.setData(
        ClipboardData(text: '$origin/min-side/invitasjon/${invite.token}'),
      );
      _inviteEmail.clear();
      final accounts = await repository.fetchAdminBandAccounts(artistId);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _inviteBusy = false;
        _status =
            'Invitasjon sendt til ${invite.email}. Lenken er også kopiert.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inviteBusy = false;
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
                  'Innstillinger for adminkonto og artistkontoer.',
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
                        'Invitér bandleder og bandmedlemmer, eller send engangskode ved glemt passord.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _artistId,
                          style: portalFieldStyle,
                          decoration: fieldDecoration(label: 'Artist'),
                          items: [
                            for (final artist in _artists)
                              DropdownMenuItem(
                                value: artist.id,
                                child: Text(artist.name),
                              ),
                          ],
                          onChanged: _selectArtist,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kontoer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_accounts.isEmpty)
                          Text(
                            'Ingen bandkontoer ennå.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.ink,
                            ),
                          )
                        else
                          for (final member in _accounts) ...[
                            Text(
                              '${member.name.isEmpty ? 'Uten navn' : member.name}'
                              ' · ${member.role}'
                              '${member.isLeader ? ' · Bandleder' : ''}'
                              '${member.email.isEmpty ? '' : ' · ${member.email}'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _inviteEmail,
                          keyboardType: TextInputType.emailAddress,
                          style: portalFieldStyle,
                          cursorColor: AppColors.ink,
                          decoration: fieldDecoration(
                            label: 'E-post til invitasjon',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _inviteRole,
                          style: portalFieldStyle,
                          cursorColor: AppColors.ink,
                          decoration: fieldDecoration(label: 'Rolle'),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _asLeader,
                              onChanged: (value) =>
                                  setState(() => _asLeader = value ?? false),
                            ),
                            const Expanded(child: Text('Invitér som bandleder')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _inviteBusy ? null : _invite,
                          child: Text(
                            _inviteBusy ? 'Sender…' : 'Send invitasjon',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Glemt passord',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
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
