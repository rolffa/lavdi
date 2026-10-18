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
  var _hasAuthSession = false;

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
      _message = null;
    });
    try {
      final preview = await repository.previewInvite(widget.token);
      if (!mounted) return;
      if (preview == null) {
        setState(() {
          _preview = null;
          _loading = false;
        });
        return;
      }
      if (preview.used) {
        setState(() {
          _preview = preview;
          _loading = false;
          _message = 'Invitasjonen er allerede brukt. Logg inn på Min side.';
        });
        return;
      }

      setState(() {
        _preview = preview;
        _loading = false;
      });

      // Inviterte er ikke artist ennå — bruk Auth-e-post, ikke currentArtist().
      final authEmail = await repository.waitForAuthEmail();
      if (!mounted) return;
      final matched = authEmail != null &&
          authEmail.toLowerCase() == preview.email.toLowerCase();
      setState(() => _hasAuthSession = matched);
      if (matched) {
        await _accept();
      } else if (authEmail != null) {
        setState(
          () => _message =
              'Du er innlogget som $authEmail, men invitasjonen er til ${preview.email}.',
        );
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
      setState(() {
        _member = member;
        _hasAuthSession = true;
      });
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
            'Sjekk e-posten. Åpne bekreftelseslenken i samme nettleser — da aktiveres kontoen her.',
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
    String? password,
  }) async {
    final repository = PortalScope.of(context).repository;
    final member = await repository.saveMyProfile(
      name: name,
      role: role,
      phone: phone,
      food: food,
      personalTech: personalTech,
    );
    final chosen = password?.trim() ?? '';
    if (chosen.isNotEmpty) {
      await repository.setArtistPassword(chosen);
    }
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
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.onImage,
                              ),
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
                              else if (_hasAuthSession)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _accept,
                                    child: Text(
                                      _busy
                                          ? 'Aktiverer…'
                                          : 'Aktiver kontoen',
                                    ),
                                  ),
                                )
                              else ...[
                                Text(
                                  'Åpne aktiveringslenken fra e-posten din. Har du ikke fått den, kan du sende på nytt under.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.onImageMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _sendEmail,
                                    child: const Text('Send e-post på nytt'),
                                  ),
                                ),
                              ],
                            ] else if (!member.profileComplete) ...[
                              Text(
                                'Fyll ut profilen og lag et passord for innlogging. Alle feltene er obligatoriske.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onImageMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              MemberProfileForm(
                                initial: member,
                                includePassword: true,
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
