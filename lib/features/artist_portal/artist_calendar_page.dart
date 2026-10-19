import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/calendar_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../data/portal_repository.dart';
import '../../models/gig.dart';
import '../../models/musician_band.dart';
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
  Map<DateTime, List<CombinedCalendarMark>> _marks = {};
  List<MusicianBand> _bands = const [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Object? _error;
  var _loading = true;
  var _saving = false;
  var _signedOut = false;
  var _hasBand = false;
  PortalRepository? _repository;

  bool get _multiBand => _bands.length > 1;

  MusicianBand? get _activeBand {
    for (final band in _bands) {
      if (band.isActive) return band;
    }
    return _bands.isEmpty ? null : _bands.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = PortalScope.of(context).repository;
    if (!identical(_repository, repository)) {
      _repository?.removeListener(_onRepo);
      _repository = repository;
      repository.addListener(_onRepo);
    }
  }

  @override
  void dispose() {
    _repository?.removeListener(_onRepo);
    super.dispose();
  }

  void _onRepo() {
    if (!mounted || _loading || _saving) return;
    _load();
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
      final bands = await repository.fetchMyBands();
      final band = await repository.fetchMyBand();
      final gigs = await repository.fetchMyGigs();
      final from = DateTime(_month.year, _month.month, 1);
      final to = DateTime(_month.year, _month.month + 1, 0);
      final days = await repository.fetchAvailability(
        artistId: session.artistId,
        from: from,
        to: to,
      );
      final combined = bands.length > 1
          ? await repository.fetchCombinedCalendar(from: from, to: to)
          : const <CombinedCalendarMark>[];
      if (!mounted) return;
      setState(() {
        _bands = bands;
        _hasBand = band != null;
        _booked = {for (final gig in gigs) dateOnly(gig.date): gig};
        _open
          ..clear()
          ..addAll(
            days
                .where((day) => day.isAvailable)
                .map((day) => dateOnly(day.date)),
          );
        _marks = _groupMarks(combined);
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

  Map<DateTime, List<CombinedCalendarMark>> _groupMarks(
    List<CombinedCalendarMark> marks,
  ) {
    final map = <DateTime, List<CombinedCalendarMark>>{};
    for (final mark in marks) {
      final key = dateOnly(mark.date);
      map.putIfAbsent(key, () => []).add(mark);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        if (a.isBooked != b.isBooked) return a.isBooked ? -1 : 1;
        return a.bandName.compareTo(b.bandName);
      });
    }
    return map;
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _reloadMonth();
  }

  Future<void> _reloadMonth() async {
    final repository = PortalScope.of(context).repository;
    final session = await repository.currentArtist();
    if (session == null || !mounted) return;
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0);
    final days = await repository.fetchAvailability(
      artistId: session.artistId,
      from: from,
      to: to,
    );
    final combined = _multiBand
        ? await repository.fetchCombinedCalendar(from: from, to: to)
        : const <CombinedCalendarMark>[];
    final gigs = await repository.fetchMyGigs();
    if (!mounted) return;
    setState(() {
      _booked = {for (final gig in gigs) dateOnly(gig.date): gig};
      _open.removeWhere(
        (day) => day.year == _month.year && day.month == _month.month,
      );
      _open.addAll(
        days.where((day) => day.isAvailable).map((day) => dateOnly(day.date)),
      );
      _marks = _groupMarks(combined);
    });
  }

  Future<void> _toggle(DateTime day) async {
    if (_saving || !_hasBand) return;
    final date = dateOnly(day);
    if (_booked.containsKey(date) || isPastDay(date, DateTime.now())) return;
    if (_multiBand) {
      final marks = _marks[date] ?? const [];
      if (marks.any((m) => m.isBooked)) return;
    }
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
      if (_multiBand) await _reloadMonth();
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
        if (!_booked.containsKey(day) &&
            !(_marks[day]?.any((m) => m.isBooked) ?? false))
          day,
    ];
    if (dates.isEmpty) return;
    setState(() => _saving = true);
    try {
      await PortalScope.of(context).repository
          .saveMyAvailability(dates: dates, available: true);
      if (!mounted) return;
      setState(() => _open.addAll(dates));
      if (_multiBand) await _reloadMonth();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(readableError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openBookedMark(CombinedCalendarMark mark) async {
    final gigId = mark.gigId;
    if (gigId == null || gigId.isEmpty) return;
    final active = _activeBand;
    if (active != null && active.bandId != mark.bandId) {
      try {
        await PortalScope.of(context).repository.setActiveBand(mark.bandId);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(readableError(error))));
        return;
      }
    }
    if (!mounted) return;
    context.go('/min-side/gig/$gigId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = monthCells(_month);
    final active = _activeBand;
    final bookedThisMonth = _collectBookedList();

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
                              _multiBand ? 'Kalender · alle band' : 'Kalender',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.onImage,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _multiBand
                                  ? 'Oversikt over ledige og opptatte dager for alle bandene dine. Hvert stempel viser hvilket band det gjelder. Klikk en dag for å åpne/lukke den for aktivt band${active == null ? '' : ' (${active.bandName})'}.'
                                  : 'Grå datoer er utilgjengelige. Klikk en dag for å gjøre den ledig. Opptatte dager er låst til den bekreftede jobben.',
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
                            if (_multiBand) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  for (final band in _bands)
                                    _BandLegend(
                                      name: band.bandName,
                                      color: bandStampColor(band.bandId),
                                      active: band.isActive,
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _saving || !_hasBand
                                    ? null
                                    : _markWeekends,
                                child: Text(
                                  _multiBand && active != null
                                      ? 'Marker helger (fre–lør) som ledig for ${active.bandName}'
                                      : 'Marker alle helger (fre–lør) som tilgjengelig denne måneden',
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
                                                  ?.copyWith(
                                                    color: AppColors.ink,
                                                  ),
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
                                                style: theme
                                                    .textTheme.labelMedium
                                                    ?.copyWith(
                                                      color: AppColors.ink,
                                                    ),
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
                                        childAspectRatio: _multiBand
                                            ? 0.72
                                            : 1,
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
                                                marks: _multiBand
                                                    ? (_marks[dateOnly(cell)] ??
                                                          const [])
                                                    : const [],
                                                multiBand: _multiBand,
                                                enabled: _hasBand && !_saving,
                                                onToggle: () => _toggle(cell),
                                                onOpenGig: (gig) => context.go(
                                                  '/min-side/gig/${gig.id}',
                                                ),
                                                onOpenMark: _openBookedMark,
                                              ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 8,
                                        children: [
                                          const _Swatch(
                                            color: AppColors.paperDeep,
                                            label: 'Utilgjengelig',
                                          ),
                                          const _Swatch(
                                            color: AppColors.available,
                                            label: 'Tilgjengelig',
                                          ),
                                          const _Swatch(
                                            color: AppColors.busy,
                                            label: 'Opptatt',
                                          ),
                                          if (_multiBand)
                                            const _Swatch(
                                              color: AppColors.ink,
                                              label: 'Stempel = band',
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
                              for (final item in bookedThisMonth) ...[
                                ArtistCard(
                                  onTap: () {
                                    final mark = item.$2;
                                    if (mark != null) {
                                      _openBookedMark(mark);
                                    } else {
                                      context.go(
                                        '/min-side/gig/${item.$1!.id}',
                                      );
                                    }
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item.$3.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          color: bandStampColor(
                                            item.$2?.bandId ??
                                                active?.bandId ??
                                                '',
                                          ),
                                          child: Text(
                                            item.$3,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      Text(
                                        item.$1 != null
                                            ? _title(item.$1!)
                                            : (item.$2?.gigTitle.isNotEmpty ==
                                                      true
                                                  ? item.$2!.gigTitle
                                                  : 'Konsert'),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(color: AppColors.ink),
                                      ),
                                      Text(
                                        formatLongDate(
                                          item.$1?.date ?? item.$2!.date,
                                        ),
                                      ),
                                      if (item.$1 != null)
                                        Text(item.$1!.organizer.venueCity),
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

  /// (gig?, mark?, bandLabel)
  List<(Gig?, CombinedCalendarMark?, String)> _collectBookedList() {
    if (!_multiBand) {
      final list =
          _booked.values
              .where(
                (gig) =>
                    gig.date.year == _month.year &&
                    gig.date.month == _month.month,
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      return [for (final gig in list) (gig, null, '')];
    }
    final seen = <String>{};
    final items = <(Gig?, CombinedCalendarMark?, String)>[];
    for (final entry in _marks.entries) {
      if (entry.key.year != _month.year || entry.key.month != _month.month) {
        continue;
      }
      for (final mark in entry.value) {
        if (!mark.isBooked) continue;
        final key = mark.gigId ?? '${mark.bandId}-${entry.key}';
        if (!seen.add(key)) continue;
        items.add((null, mark, mark.bandName));
      }
    }
    items.sort(
      (a, b) => (a.$2?.date ?? DateTime(0)).compareTo(b.$2?.date ?? DateTime(0)),
    );
    return items;
  }
}

class _BandLegend extends StatelessWidget {
  const _BandLegend({
    required this.name,
    required this.color,
    required this.active,
  });

  final String name;
  final Color color;
  final bool active;

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
        const SizedBox(width: 6),
        Text(
          active ? '$name (aktiv)' : name,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.onImage,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AvailabilityDay extends StatelessWidget {
  const _AvailabilityDay({
    required this.day,
    required this.open,
    required this.gig,
    required this.marks,
    required this.multiBand,
    required this.enabled,
    required this.onToggle,
    required this.onOpenGig,
    required this.onOpenMark,
  });

  final DateTime day;
  final bool open;
  final Gig? gig;
  final List<CombinedCalendarMark> marks;
  final bool multiBand;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<Gig> onOpenGig;
  final ValueChanged<CombinedCalendarMark> onOpenMark;

  @override
  Widget build(BuildContext context) {
    final past = isPastDay(day, DateTime.now());
    final bookedMarks = marks.where((m) => m.isBooked).toList();
    final openMarks = marks.where((m) => m.isAvailable).toList();
    final booked = gig != null || bookedMarks.isNotEmpty;
    final isOpen = open || openMarks.isNotEmpty;
    final today = isSameDay(day, DateTime.now());
    final Color background;
    final Color foreground;
    if (booked) {
      background = AppColors.busy;
      foreground = Colors.white;
    } else if (isOpen && !past) {
      background = AppColors.available;
      foreground = Colors.white;
    } else {
      background = AppColors.paperDeep;
      foreground = AppColors.muted;
    }
    final canToggle = enabled && !booked && !past;
    final stampMarks = booked ? bookedMarks : openMarks;
    final labelParts = <String>[
      if (booked) 'Opptatt ${day.day}' else if (isOpen) 'Tilgjengelig ${day.day}' else 'Utilgjengelig ${day.day}',
      for (final mark in stampMarks) mark.bandName,
    ];

    return Semantics(
      button: booked || canToggle,
      label: labelParts.join('. '),
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
              ? () {
                  if (gig != null) {
                    onOpenGig(gig!);
                  } else if (bookedMarks.isNotEmpty) {
                    onOpenMark(bookedMarks.first);
                  }
                }
              : canToggle
              ? onToggle
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                    height: 1.1,
                  ),
                ),
                if (multiBand && stampMarks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  for (final mark in stampMarks.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          color: booked
                              ? Colors.black.withValues(alpha: 0.35)
                              : bandStampColor(mark.bandId),
                          child: Text(
                            bandStampLabel(mark.bandName, max: 7),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (stampMarks.length > 2)
                    Text(
                      '+${stampMarks.length - 2}',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ],
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
