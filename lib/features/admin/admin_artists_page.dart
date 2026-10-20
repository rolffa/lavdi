import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
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
  String? _openingId;
  String? _status;

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
      final artists =
          await PortalScope.of(context).repository.fetchAdminArtists();
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

  Future<void> _openPortal(Artist artist) async {
    if (_openingId != null) return;
    setState(() {
      _openingId = artist.id;
      _error = null;
      _status = null;
    });
    try {
      await PortalScope.of(context).repository.openArtistPortalAsAdmin(artist.id);
      if (!mounted) return;
      context.go('/min-side');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _inviteLeader(Artist artist) async {
    final result = await showDialog<_InviteDraft>(
      context: context,
      builder: (context) => _InviteMemberDialog(
        artistName: artist.name,
        asLeader: true,
      ),
    );
    if (result == null || !mounted) return;
    await _sendInvite(artist, result);
  }

  Future<void> _inviteMember(Artist artist) async {
    final result = await showDialog<_InviteDraft>(
      context: context,
      builder: (context) => _InviteMemberDialog(
        artistName: artist.name,
        asLeader: false,
      ),
    );
    if (result == null || !mounted) return;
    await _sendInvite(artist, result);
  }

  Future<void> _sendInvite(Artist artist, _InviteDraft draft) async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      final invite = await repository.adminInviteBandMember(
        artistId: artist.id,
        email: draft.email,
        role: draft.role,
        asLeader: draft.asLeader,
      );
      final origin = AppConfig.environment.publicSiteUrl;
      final link = '$origin/min-side/invitasjon/${invite.token}';
      await Clipboard.setData(ClipboardData(text: link));
      try {
        await repository.sendInviteEmail(invite.token);
      } catch (emailError) {
        if (!mounted) return;
        setState(() {
          _status =
              'Invitasjon opprettet for ${artist.name}, men e-post feilet: '
              '${readableError(emailError)} Reservelenke er kopiert.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _status =
            'Invitasjon som ${invite.role} sendt til ${invite.email} for '
            '${artist.name}. Lenken er også kopiert.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
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
            maxWidth: 820,
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
                  'Publiser eller skjul artistsider, inviter bandleder eller '
                  'medlem, og åpne artistportalen direkte uten å logge inn på nytt.',
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
                  if (_status != null) ...[
                    Text(
                      _status!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.onImage,
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
                            _ArtistAdminRow(
                              artist: _artists[i],
                              busy: _saving.contains(_artists[i].id),
                              opening: _openingId == _artists[i].id,
                              onChanged: (value) =>
                                  _toggle(_artists[i], value),
                              onInviteLeader: () =>
                                  _inviteLeader(_artists[i]),
                              onInviteMember: () =>
                                  _inviteMember(_artists[i]),
                              onOpenPortal: () => _openPortal(_artists[i]),
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

class _InviteDraft {
  const _InviteDraft({
    required this.email,
    required this.role,
    required this.asLeader,
  });
  final String email;
  final String role;
  final bool asLeader;
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({
    required this.artistName,
    required this.asLeader,
  });

  final String artistName;
  final bool asLeader;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final _email = TextEditingController();
  final _role = TextEditingController(text: 'Musiker');

  @override
  void dispose() {
    _email.dispose();
    _role.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    if (widget.asLeader) {
      Navigator.of(context).pop(
        _InviteDraft(email: email, role: 'Bandleder', asLeader: true),
      );
      return;
    }
    final role = _role.text.trim().isEmpty ? 'Musiker' : _role.text.trim();
    final lowered = role.toLowerCase();
    if (lowered == 'bandleder' || lowered == 'leder') return;
    Navigator.of(context).pop(
      _InviteDraft(email: email, role: role, asLeader: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.asLeader
            ? 'Inviter bandleder til ${widget.artistName}'
            : 'Inviter medlem til ${widget.artistName}',
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.asLeader
                  ? 'Bandleder får full tilgang til artistportalen.'
                  : 'Velg rolle for medlemmet (musiker, lydtekniker, turnéleder).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(
                label: widget.asLeader
                    ? 'E-post til bandleder'
                    : 'E-post til medlem',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (!widget.asLeader) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _role,
                style: portalFieldStyle,
                cursorColor: AppColors.ink,
                decoration: fieldDecoration(
                  label: 'Rolle',
                  helperText: 'Musiker, lydtekniker eller turnéleder',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final role in const [
                    'Musiker',
                    'Lydtekniker',
                    'Turnéleder',
                  ])
                    TextButton(
                      onPressed: () => setState(() => _role.text = role),
                      child: Text(role),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Send invitasjon'),
        ),
      ],
    );
  }
}

class _ArtistAdminRow extends StatelessWidget {
  const _ArtistAdminRow({
    required this.artist,
    required this.busy,
    required this.opening,
    required this.onChanged,
    required this.onInviteLeader,
    required this.onInviteMember,
    required this.onOpenPortal,
  });

  final Artist artist;
  final bool busy;
  final bool opening;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInviteLeader;
  final VoidCallback onInviteMember;
  final VoidCallback onOpenPortal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;
          final publish = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                artist.published ? 'Publisert' : 'Avpublisert',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 8),
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
          );
          final inviteLeaderButton = TextButton(
            onPressed: onInviteLeader,
            child: const Text('Inviter bandleder'),
          );
          final inviteMemberButton = TextButton(
            onPressed: onInviteMember,
            child: const Text('Inviter medlem'),
          );
          final openButton = TextButton(
            onPressed: opening ? null : onOpenPortal,
            child: Text(
              opening ? 'Åpner…' : 'Åpne artistportal',
            ),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artist.name, style: theme.textTheme.titleMedium),
                if (artist.tagline.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    artist.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                publish,
                inviteLeaderButton,
                inviteMemberButton,
                openButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artist.name, style: theme.textTheme.titleMedium),
                    if (artist.tagline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        artist.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              publish,
              const SizedBox(width: 4),
              inviteLeaderButton,
              inviteMemberButton,
              openButton,
            ],
          );
        },
      ),
    );
  }
}
