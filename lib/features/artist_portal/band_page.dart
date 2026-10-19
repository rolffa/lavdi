import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/band.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class BandPage extends StatefulWidget {
  const BandPage({super.key});

  @override
  State<BandPage> createState() => _BandPageState();
}

class _BandPageState extends State<BandPage> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _tech = TextEditingController();
  final _hospitality = TextEditingController();
  final _inviteEmail = TextEditingController();
  final _inviteRole = TextEditingController();
  BandOverview? _overview;
  Object? _error;
  String? _message;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _tech.dispose();
    _hospitality.dispose();
    _inviteEmail.dispose();
    _inviteRole.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await repository.ensureMyBand();
      if (!mounted) return;
      _name.text = overview.band.name;
      _contact.text = overview.band.contact;
      _tech.text = overview.band.sharedTech;
      _hospitality.text = overview.band.sharedHospitality;
      if (overview.members.isEmpty && _inviteRole.text.trim().isEmpty) {
        _inviteRole.text = 'Bandleder';
      }
      setState(() {
        _overview = overview;
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

  Future<void> _saveBand() async {
    await _run(() async {
      final band = await PortalScope.of(context).repository.updateBand(
        name: _name.text,
        contact: _contact.text,
        sharedTech: _tech.text,
        sharedHospitality: _hospitality.text,
      );
      _overview = BandOverview(
        band: band,
        me: _overview!.me,
        members: _overview!.members,
        invites: _overview!.invites,
      );
      _message = 'Bandet er oppdatert.';
    });
  }

  Future<void> _invite() async {
    await _run(() async {
      final role = _inviteRole.text.trim().isEmpty &&
              (_overview?.members.isEmpty ?? true)
          ? 'Bandleder'
          : _inviteRole.text;
      final invite = await PortalScope.of(context).repository
          .inviteMember(email: _inviteEmail.text, role: role);
      _inviteEmail.clear();
      _inviteRole.clear();
      _flash(
        'Invitasjon sendt til ${invite.email} som ${invite.role}.',
      );
      await _load();
    });
  }

  Future<void> _resendInvite(BandInvite invite) async {
    await _run(() async {
      await PortalScope.of(context).repository.sendInviteEmail(invite.token);
      _flash('Aktiveringslenke sendt på nytt til ${invite.email}.');
    });
  }

  Future<void> _revoke(BandInvite invite) async {
    await _run(() async {
      await PortalScope.of(context).repository.revokeInvite(invite.id);
      _message = 'Invitasjonen er trukket.';
      await _load();
    });
  }

  bool _isSoleLeader(BandMember member) {
    if (!member.isLeader) return false;
    final leaders =
        _overview?.members.where((item) => item.isLeader).length ?? 0;
    return leaders <= 1;
  }

  Future<void> _removeMember(BandMember member) async {
    if (_isSoleLeader(member)) {
      _flash('Kan ikke fjerne den eneste bandlederen.');
      return;
    }
    final label = member.name.isEmpty ? 'dette medlemmet' : member.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fjern medlem'),
          content: Text('Vil du fjerne $label fra bandet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Fjern'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await PortalScope.of(context).repository.removeMember(member.id);
      _flash('Medlemmet er fjernet.');
      await _load();
    });
  }

  void _flash(String message) {
    setState(() => _message = message);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) _flash(readableError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Band og crew',
                              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Felles tech og hospitality samles i riderne. Kjøreplanen holder seg til tid og logistikk.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_message != null) ...[
                              Text(
                                _message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onImage,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_overview != null) _editor(),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _editor() {
    final overview = _overview!;
    final theme = Theme.of(context);
    final origin = Uri.base.origin;
    final canEdit = !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BandBox(
          title: 'Bandinfo',
          caption: 'Navn, kontakt og felles oppsett',
          tone: _BandTone.info,
          children: [
            TextField(
              controller: _name,
              enabled: canEdit,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(label: 'Bandnavn'),
            ),
            TextField(
              controller: _contact,
              enabled: canEdit,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(
                label: 'Kontaktinfo',
                helperText: 'Vises på hospitality-rideren',
              ),
            ),
            TextField(
              controller: _hospitality,
              enabled: canEdit,
              minLines: 3,
              maxLines: 6,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(
                label: 'Felles backstage og losji',
                alignLabelWithHint: true,
              ),
            ),
            TextField(
              controller: _tech,
              enabled: canEdit,
              minLines: 3,
              maxLines: 6,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(
                label: 'Felles teknisk oppsett',
                alignLabelWithHint: true,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _saveBand,
                child: const Text('Lagre bandinfo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _BandBox(
          title: 'Medlemmer',
          caption: 'Hvem som er med i bandet',
          tone: _BandTone.members,
          children: [
            if (overview.members.isEmpty)
              Text(
                'Ingen medlemmer ennå.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              )
            else
              for (final member in overview.members)
                ArtistCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name.isEmpty
                            ? 'Profil ikke utfylt'
                            : member.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        member.role.isEmpty ? 'Rolle ikke satt' : member.role,
                      ),
                      if (member.isLeader)
                        Text(
                          'Bandleder',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      if (!member.profileComplete)
                        Text(
                          'Profilen er ikke ferdig',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.busy,
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => _removeMember(member),
                        child: const Text('Fjern'),
                      ),
                    ],
                  ),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => context.go('/min-side/profil'),
                child: const Text('Min profil'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _BandBox(
          title: 'Inviter',
          caption: 'Send e-post til et nytt medlem',
          tone: _BandTone.invite,
          children: [
            Text(
              overview.members.isEmpty
                  ? 'Ingen medlemmer ennå. Den første som inviteres blir bandleder og får e-post med aktiveringslenke.'
                  : 'Alle i bandet kan invitere. Personen får en e-post med aktiveringslenke. Velg Bandleder for å invitere en ekstra leder.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            TextField(
              controller: _inviteEmail,
              keyboardType: TextInputType.emailAddress,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(label: 'E-post'),
            ),
            TextField(
              controller: _inviteRole,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              decoration: fieldDecoration(
                label: 'Rolle',
                helperText: overview.members.isEmpty
                    ? 'Første invitasjon settes til Bandleder'
                    : 'Bandleder, musiker, lydtekniker eller turnéleder',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final role in const [
                  'Bandleder',
                  'Musiker',
                  'Lydtekniker',
                  'Turnéleder',
                ])
                  ActionChip(
                    label: Text(role),
                    onPressed: () {
                      _inviteRole.text = role;
                      setState(() {});
                    },
                  ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _invite,
                child: Text(
                  overview.members.isEmpty
                      ? 'Inviter bandleder'
                      : 'Send invitasjon',
                ),
              ),
            ),
            for (final invite in overview.invites)
              ArtistCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invite.email} · ${invite.role}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Venter på aktivering',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _saving ? null : () => _resendInvite(invite),
                          child: const Text('Send e-post på nytt'),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          '$origin/min-side/invitasjon/${invite.token}',
                                    ),
                                  );
                                  if (!mounted) return;
                                  _flash('Reservelenke er kopiert.');
                                },
                          child: const Text('Kopier reservelenke'),
                        ),
                        TextButton(
                          onPressed: _saving ? null : () => _revoke(invite),
                          child: const Text('Trekk tilbake'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

enum _BandTone { info, members, invite }

class _BandBox extends StatelessWidget {
  const _BandBox({
    required this.title,
    required this.caption,
    required this.tone,
    required this.children,
  });

  final String title;
  final String caption;
  final _BandTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color borderColor;
    final Color headerColor;
    final Color headerText;
    final Color captionColor;
    final Color bodyColor;
    switch (tone) {
      case _BandTone.info:
        borderColor = AppColors.ink;
        headerColor = AppColors.ink;
        headerText = AppColors.surface;
        captionColor = AppColors.paperDeep;
        bodyColor = AppColors.surface;
      case _BandTone.members:
        borderColor = AppColors.available;
        headerColor = AppColors.available;
        headerText = AppColors.surface;
        captionColor = const Color(0xFFD7E8DC);
        bodyColor = const Color(0xFFF4F8F5);
      case _BandTone.invite:
        borderColor = const Color(0xFFC9A227);
        headerColor = const Color(0xFFF0C400);
        headerText = AppColors.ink;
        captionColor = const Color(0xFF6B5410);
        bodyColor = const Color(0xFFFFF8E6);
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bodyColor,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: headerColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: headerText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: captionColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0) const SizedBox(height: 12),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
