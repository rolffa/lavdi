import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      final activeId = bands
          .where((item) => item.isActive)
          .map((item) => item.bandId)
          .firstOrNull;
      if (activeId != band.bandId) {
        throw PortalException(
          'Bandbyttet ble ikke lagret. Oppdater siden, eller kontakt support.',
        );
      }
      setState(() => _bands = bands);
      final path = GoRouterState.of(context).uri.path;
      context.go(
        Uri(path: path, queryParameters: {'band': band.bandId}).toString(),
      );
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Row(
              children: [
                Text(
                  'Band',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _bands.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          _BandChip(
                            band: _bands[i],
                            busy: _switching,
                            onTap: () => _select(_bands[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
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
    final label = band.role.isEmpty
        ? band.bandName
        : '${band.bandName} · ${band.role}';
    return Material(
      color: selected ? stamp : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? stamp : AppColors.line),
      ),
      child: InkWell(
        onTap: busy || selected ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
