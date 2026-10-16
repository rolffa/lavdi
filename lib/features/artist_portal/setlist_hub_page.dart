import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/gig.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class SetlistHubPage extends StatefulWidget {
  const SetlistHubPage({super.key});

  @override
  State<SetlistHubPage> createState() => _SetlistHubPageState();
}

class _SetlistHubPageState extends State<SetlistHubPage> {
  List<(Gig, bool)> _rows = const [];
  Object? _error;
  var _loading = true;
  var _signedOut = false;

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
      _signedOut = false;
    });
    try {
      final session = await repository.currentArtist();
      if (session == null) {
        if (!mounted) return;
        setState(() {
          _signedOut = true;
          _loading = false;
        });
        return;
      }
      final gigs = await repository.fetchMyGigs();
      final rows = <(Gig, bool)>[];
      for (final gig in gigs) {
        final setlist = await repository.fetchSetlist(gig.id);
        rows.add((gig, setlist.confirmed));
      }
      rows.sort((a, b) => b.$1.date.compareTo(a.$1.date));
      if (!mounted) return;
      setState(() {
        _rows = rows;
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
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                ArtistFrame(
                  child: _signedOut
                      ? const Text('Logg inn for å se settlistene.')
                      : _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Settliste',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Velg konserten settlisten gjelder. Låtene hentes fra repertoaret.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () =>
                                    context.go('/min-side/repertoar'),
                                child: const Text('Mitt repertoar'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_rows.isEmpty)
                              const Text(
                                'Ingen konserter å legge settliste på ennå.',
                              )
                            else
                              for (final row in _rows) ...[
                                ArtistCard(
                                  onTap: () => context.go(
                                    '/min-side/gig/${row.$1.id}/settliste',
                                  ),
                                  child: SizedBox(
                                    height: 116,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _title(row.$1),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatLongDate(row.$1.date),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          row.$1.organizer.venueCity
                                                  .trim()
                                                  .isEmpty
                                              ? ' '
                                              : row.$1.organizer.venueCity,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Text(
                                          row.$2
                                              ? 'Bekreftet'
                                              : 'Ikke bekreftet',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: row.$2
                                                    ? AppColors.available
                                                    : AppColors.busy,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

String _title(Gig gig) {
  if (gig.production.eventName.trim().isNotEmpty) {
    return gig.production.eventName.trim();
  }
  if (gig.organizer.venueCity.trim().isNotEmpty) {
    return gig.organizer.venueCity.trim();
  }
  return 'Konsert';
}
