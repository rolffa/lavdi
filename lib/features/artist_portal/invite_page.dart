import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/band.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';
import 'profile_form.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key, required this.token});

  final String token;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  BandInvitePreview? _preview;
  BandMember? _member;
  Object? _error;
  String? _message;
  var _loading = true;
  var _busy = false;

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
      final preview = await repository.previewInvite(widget.token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
      final session = await repository.currentArtist();
      if (!mounted || preview == null || session == null) return;
      if (session.email.toLowerCase() == preview.email.toLowerCase()) {
        await _accept();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final member = await PortalScope.of(context).repository
          .acceptInvite(widget.token);
      if (!mounted) return;
      setState(() => _member = member);
    } catch (error) {
      if (mounted) setState(() => _message = readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendEmail() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await PortalScope.of(context).repository.sendInviteEmail(widget.token);
      if (!mounted) return;
      setState(
        () => _message =
            'Sjekk e-posten. Lenken aktiverer kontoen på denne siden.',
      );
    } catch (error) {
      if (mounted) setState(() => _message = readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfile({
    required String name,
    required String role,
    required String phone,
    required String food,
    required String personalTech,
  }) async {
    final member = await PortalScope.of(context).repository.saveMyProfile(
      name: name,
      role: role,
      phone: phone,
      food: food,
      personalTech: personalTech,
    );
    if (!mounted) return;
    setState(() => _member = member);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = PortalScope.of(context).demoMode;
    final preview = _preview;
    final member = _member;
    return PortalScaffold(
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
                      : preview == null
                      ? const Text('Invitasjonen finnes ikke.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invitasjon',
                              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${preview.bandName} har invitert ${preview.email} som ${preview.role}.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_message != null) ...[
                              Text(
                                _message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onImage,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (member == null) ...[
                              if (demo)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _accept,
                                    child: const Text('Aktiver kontoen'),
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _sendEmail,
                                    child: const Text('Send aktiveringslenke'),
                                  ),
                                ),
                            ] else if (!member.profileComplete) ...[
                              Text(
                                'Fyll ut profilen for å fortsette. Alle feltene er obligatoriske.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onImageMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              MemberProfileForm(
                                initial: member,
                                onSave: _saveProfile,
                              ),
                            ] else ...[
                              const Text('Profilen er lagret.'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => context.go('/min-side'),
                                child: const Text('Gå til min side'),
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
