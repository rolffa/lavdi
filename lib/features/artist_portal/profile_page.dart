import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/band.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';
import 'profile_form.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  BandMember? _member;
  Object? _error;
  var _loading = true;

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
      final overview = await repository.fetchMyBand();
      if (!mounted) return;
      setState(() {
        _member = overview?.me;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = _member;
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
                      : member == null
                      ? const Text('Du er ikke med i et band ennå.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ArtistBackButton(
                              label: 'Band og crew',
                              path: '/min-side/band',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Min profil',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Navn, rolle, telefon, mat og tekniske behov samles i riderne.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            MemberProfileForm(
                              initial: member,
                              onSave:
                                  ({
                                    required String name,
                                    required String role,
                                    required String phone,
                                    required String food,
                                    required String personalTech,
                                  }) async {
                                    await PortalScope.of(context).repository
                                        .saveMyProfile(
                                          name: name,
                                          role: role,
                                          phone: phone,
                                          food: food,
                                          personalTech: personalTech,
                                        );
                                    if (context.mounted) {
                                      context.go('/min-side/band');
                                    }
                                  },
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
