import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/calendar_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/gig.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class ArtistCalendarPage extends StatefulWidget {
  const ArtistCalendarPage({super.key});

  @override
  State<ArtistCalendarPage> createState() => _ArtistCalendarPageState();
}

class _ArtistCalendarPageState extends State<ArtistCalendarPage> {
  final Set<DateTime> _open = {};
  Map<DateTime, Gig> _booked = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Object? _error;
  var _loading = true;
  var _saving = false;
  var _signedOut = false;
  var _hasBand = false;

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
      final band = await repository.fetchMyBand();
      final gigs = await repository.fetchMyGigs();
      final days = await repository.fetchAvailability(
        artistId: session.artistId,
        from: DateTime(_month.year, _month.month, 1),
        to: DateTime(_month.year, _month.month + 1, 0),
      );
      if (!mounted) return;
      setState(() {
        _hasBand = band != null;
        _booked = {for (final gig in gigs) dateOnly(gig.date): gig};
        _open
          ..clear()
          ..addAll(
            days
                .where((day) => day.isAvailable)
                .map((day) => dateOnly(day.date)),
          );
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

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _reloadMonth();
  }

  Future<void> _reloadMonth() async {
    final repository = PortalScope.of(context).repository;
    final session = await repository.currentArtist();
    if (session == null || !mounted) return;
    final days = await repository.fetchAvailability(
      artistId: session.artistId,
      from: DateTime(_month.year, _month.month, 1),
      to: DateTime(_month.year, _month.month + 1, 0),
    );
    if (!mounted) return;
    setState(() {
      _open.removeWhere(
        (day) => day.year == _month.year && day.month == _month.month,
      );
      _open.addAll(
        days.where((day) => day.isAvailable).map((day) => dateOnly(day.date)),
      );
    });
  }

  Future<void> _toggle(DateTime day) async {
    if (_saving || !_hasBand) return;
    final date = dateOnly(day);
    if (_booked.containsKey(date) || isPastDay(date, DateTime.now())) return;
    final opening = !_open.contains(date);
    setState(() => _saving = true);
    try {
      await PortalScope.of(context).repository
          .saveMyAvailability(dates: [date], available: opening);
      if (!mounted) return;
      setState(() {
        if (opening) {
          _open.add(date);
        } else {
          _open.remove(date);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(readableError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markWeekends() async {
    if (_saving || !_hasBand) return;
    final dates = [
      for (final day in weekendDaysInMonth(_month, notBefore: DateTime.now()))
        if (!_booked.containsKey(day)) day,
    ];
    if (dates.isEmpty) return;
    setState(() => _saving = true);
    try {
      await PortalScope.of(context).repository
          .saveMyAvailability(dates: dates, available: true);
      if (!mounted) return;
      setState(() => _open.addAll(dates));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(readableError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = monthCells(_month);
    final bookedThisMonth =
        _booked.values
            .where(
              (gig) =>
                  gig.date.year == _month.year &&
                  gig.date.month == _month.month,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                ArtistFrame(
                  child: _signedOut
                      ? const Text('Logg inn for å se kalenderen.')
                      : _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kalender',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Grå datoer er utilgjengelige. Klikk en dag for å gjøre den ledig. Opptatte dager er låst til den bekreftede jobben.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            if (!_hasBand) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Opprett bandet under Band/crew før du kan åpne datoer.',
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _saving || !_hasBand
                                    ? null
                                    : _markWeekends,
                                child: const Text(
                                  'Marker alle helger (fre–lør) som tilgjengelig denne måneden',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DecoratedBox(
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                border: Border.fromBorderSide(
                                  BorderSide(color: AppColors.line),
                                ),
                              ),
                              child: InkSurface(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    16,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'Forrige måned',
                                            onPressed: _saving
                                                ? null
                                                : () => _changeMonth(-1),
                                            icon: const Icon(
                                              Icons.chevron_left,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              formatMonth(_month),
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(color: AppColors.ink),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Neste måned',
                                            onPressed: _saving
                                                ? null
                                                : () => _changeMonth(1),
                                            icon: const Icon(
                                              Icons.chevron_right,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          for (final label in calendarWeekdays)
                                            Expanded(
                                              child: Text(
                                                label,
                                                textAlign: TextAlign.center,
                                                style: theme.textTheme.labelMedium
                                                    ?.copyWith(color: AppColors.ink),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      GridView.count(
                                        crossAxisCount: 7,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        mainAxisSpacing: 6,
                                        crossAxisSpacing: 6,
                                        children: [
                                          for (final cell in cells)
                                            if (cell == null)
                                              const SizedBox.shrink()
                                            else
                                              _AvailabilityDay(
                                                day: cell,
                                                open: _open.contains(
                                                  dateOnly(cell),
                                                ),
                                                gig: _booked[dateOnly(cell)],
                                                enabled: _hasBand && !_saving,
                                                onToggle: () => _toggle(cell),
                                                onOpenGig: (gig) => context.go(
                                                  '/min-side/gig/${gig.id}',
                                                ),
                                              ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Wrap(
                                        spacing: 16,
                                        runSpacing: 8,
                                        children: [
                                          _Swatch(
                                            color: AppColors.paperDeep,
                                            label: 'Utilgjengelig',
                                          ),
                                          _Swatch(
                                            color: AppColors.available,
                                            label: 'Tilgjengelig',
                                          ),
                                          _Swatch(
                                            color: AppColors.busy,
                                            label: 'Opptatt',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (bookedThisMonth.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Opptatt denne måneden',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.onImage,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final gig in bookedThisMonth) ...[
                                ArtistCard(
                                  onTap: () =>
                                      context.go('/min-side/gig/${gig.id}'),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _title(gig),
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      Text(formatLongDate(gig.date)),
                                      Text(gig.organizer.venueCity),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _AvailabilityDay extends StatelessWidget {
  const _AvailabilityDay({
    required this.day,
    required this.open,
    required this.gig,
    required this.enabled,
    required this.onToggle,
    required this.onOpenGig,
  });

  final DateTime day;
  final bool open;
  final Gig? gig;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<Gig> onOpenGig;

  @override
  Widget build(BuildContext context) {
    final past = isPastDay(day, DateTime.now());
    final booked = gig != null;
    final today = isSameDay(day, DateTime.now());
    final Color background;
    final Color foreground;
    if (booked) {
      background = AppColors.busy;
      foreground = Colors.white;
    } else if (open && !past) {
      background = AppColors.available;
      foreground = Colors.white;
    } else {
      background = AppColors.paperDeep;
      foreground = AppColors.muted;
    }
    final canToggle = enabled && !booked && !past;
    return Semantics(
      button: booked || canToggle,
      label: booked
          ? 'Opptatt ${day.day}. Åpne jobben'
          : open
          ? 'Tilgjengelig ${day.day}'
          : 'Utilgjengelig ${day.day}',
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: today ? AppColors.ink : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: booked
              ? () => onOpenGig(gig!)
              : canToggle
              ? onToggle
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: today ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox(width: 12, height: 12),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.ink),
        ),
      ],
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
