import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../data/portal_repository.dart';
import '../../models/musician_band.dart';

/// Compact band switcher for musicians in more than one band.
class BandSwitcherBar extends StatefulWidget {
  const BandSwitcherBar({super.key});

  @override
  State<BandSwitcherBar> createState() => _BandSwitcherBarState();
}

class _BandSwitcherBarState extends State<BandSwitcherBar> {
  List<MusicianBand> _bands = const [];
  var _loading = true;
  var _switching = false;
  PortalRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = PortalScope.of(context).repository;
    if (!identical(_repository, repository)) {
      _repository?.removeListener(_onRepo);
      _repository = repository;
      repository.addListener(_onRepo);
      _load();
    }
  }

  @override
  void dispose() {
    _repository?.removeListener(_onRepo);
    super.dispose();
  }

  void _onRepo() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final bands = await repository.fetchMyBands();
      if (!mounted) return;
      setState(() {
        _bands = bands;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bands = const [];
        _loading = false;
      });
    }
  }

  Future<void> _select(MusicianBand band) async {
    if (_switching || band.isActive) return;
    final repository = _repository;
    if (repository == null) return;
    setState(() => _switching = true);
    try {
      await repository.setActiveBand(band.bandId);
      if (!mounted) return;
      final bands = await repository.fetchMyBands();
      if (!mounted) return;
      setState(() => _bands = bands);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Byttet til ${band.bandName}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(readableError(error))),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _bands.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final active = _bands.where((b) => b.isActive).firstOrNull ?? _bands.first;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aktivt band',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Du jobber nå i ${active.bandName}'
                  '${active.role.isEmpty ? '' : ' · ${active.role}'}. '
                  'Bytt under for å redigere profil, rider og kalender for et annet band.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final band in _bands)
                      _BandChip(
                        band: band,
                        busy: _switching,
                        onTap: () => _select(band),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.band,
    required this.busy,
    required this.onTap,
  });

  final MusicianBand band;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stamp = bandStampColor(band.bandId);
    final selected = band.isActive;
    return Material(
      color: selected ? stamp : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? stamp : AppColors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: busy || selected ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                band.bandName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (band.role.isNotEmpty)
                Text(
                  band.role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
