import 'package:flutter/material.dart';

import '../../core/calendar_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist.dart';
import '../shell/portal_scaffold.dart';
import 'admin_login.dart';

class AdminCalendarPage extends StatefulWidget {
  const AdminCalendarPage({super.key});

  @override
  State<AdminCalendarPage> createState() => _AdminCalendarPageState();
}

class _AdminCalendarPageState extends State<AdminCalendarPage> {
  List<Artist> _artists = [];
  String? _artistId;
  var _loadingArtists = false;
  Object? _loadError;

  late DateTime _today;
  late DateTime _month;
  Map<DateTime, bool> _availability = {};
  final Set<DateTime> _booked = {};
  var _loadingMonth = false;
  DateTime? _savingDay;
  String? _saveMessage;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = dateOnly(now);
    _month = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PortalScope.of(context).repository.isAdminSignedIn) _loadArtists();
    });
  }

  Future<void> _loadArtists() async {
    setState(() {
      _loadingArtists = true;
      _loadError = null;
    });
    try {
      final artists =
          (await PortalScope.of(context).repository.fetchAdminArtists()).toList();
      artists.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _artists = artists;
        _artistId = artists.isEmpty ? null : artists.first.id;
        _loadingArtists = false;
      });
      if (artists.isNotEmpty) await _loadMonth();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingArtists = false;
        _loadError = error;
      });
    }
  }

  Future<void> _loadMonth() async {
    final artistId = _artistId;
    if (artistId == null) return;
    setState(() => _loadingMonth = true);
    try {
      final days = await PortalScope.of(context).repository.fetchAvailability(
        artistId: artistId,
        from: _month,
        to: DateTime(_month.year, _month.month + 1, 0),
      );
      if (!mounted || artistId != _artistId) return;
      setState(() {
        _availability = {
          for (final day in days) dateOnly(day.date): day.isAvailable,
        };
        _booked
          ..clear()
          ..addAll({
            for (final day in days)
              if (day.isBooked) dateOnly(day.date),
          });
        _loadingMonth = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMonth = false;
        _saveError = readableError(error);
      });
    }
  }

  bool _canMove(int delta) {
    final target = DateTime(_month.year, _month.month + delta, 1);
    final earliest = DateTime(_today.year, _today.month, 1);
    final latest = DateTime(_today.year, _today.month + bookingHorizonMonths, 1);
    return !target.isBefore(earliest) && !target.isAfter(latest);
  }

  Future<void> _changeMonth(int delta) async {
    if (!_canMove(delta) || _savingDay != null) return;
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    await _loadMonth();
  }

  Future<void> _toggle(DateTime day) async {
    final artistId = _artistId;
    if (artistId == null || _savingDay != null) return;
    final key = dateOnly(day);
    if (_booked.contains(key)) return;
    final previous = _availability[key];
    final next = previous != true;
    setState(() {
      _savingDay = key;
      _availability[key] = next;
      _saveError = null;
      _saveMessage = null;
    });
    try {
      await PortalScope.of(context).repository.setAvailability(
        artistId: artistId,
        date: key,
        isAvailable: next,
      );
      if (!mounted) return;
      setState(() {
        _savingDay = null;
        _saveMessage = next ? 'Lagret som ledig' : 'Lagret som opptatt';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingDay = null;
        if (previous == null) {
          _availability.remove(key);
        } else {
          _availability[key] = previous;
        }
        _saveError = readableError(error);
      });
    }
  }

  Future<void> _markWeekends() async {
    final artistId = _artistId;
    if (artistId == null || _savingDay != null) return;
    final dates = [
      for (final day in weekendDaysInMonth(_month, notBefore: _today))
        if (!_booked.contains(day) && _availability[day] != true) day,
    ];
    if (dates.isEmpty) {
      setState(() {
        _saveMessage = 'Alle helger denne måneden er allerede ledige.';
        _saveError = null;
      });
      return;
    }
    setState(() {
      _savingDay = dates.first;
      _saveError = null;
      _saveMessage = null;
      for (final day in dates) {
        _availability[day] = true;
      }
    });
    try {
      final repository = PortalScope.of(context).repository;
      for (final day in dates) {
        await repository.setAvailability(
          artistId: artistId,
          date: day,
          isAvailable: true,
        );
      }
      if (!mounted) return;
      setState(() {
        _savingDay = null;
        _saveMessage =
            'Markerte ${dates.length} helgedager som ledig denne måneden.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingDay = null;
        _saveError = readableError(error);
      });
      await _loadMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 760,
            child: PortalScope.of(context).repository.isAdminSignedIn
                ? _editor(context)
                : AdminLogin(onSignedIn: _loadArtists),
          ),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingArtists) {
      return const CenteredStatus(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return ErrorRetry(
        message: readableError(_loadError!),
        onRetry: _loadArtists,
      );
    }
    if (_artists.isEmpty) {
      return const Text('Ingen artister er lagt inn ennå.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KALENDER',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text('Tilgjengelighet', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
        const SizedBox(height: 10),
        Text(
          'Klikk en dato for å veksle mellom ledig og opptatt. Endringen lagres med en gang.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _artistId,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
          decoration: const InputDecoration(labelText: 'Artist'),
          items: [
            for (final artist in _artists)
              DropdownMenuItem(value: artist.id, child: Text(artist.name)),
          ],
          onChanged: _savingDay != null
              ? null
              : (value) {
                  if (value == null || value == _artistId) return;
                  setState(() {
                    _artistId = value;
                    _saveMessage = null;
                    _saveError = null;
                  });
                  _loadMonth();
                },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _savingDay != null || _artistId == null
                ? null
                : _markWeekends,
            child: const Text(
              'Marker alle helger (fre–lør) som tilgjengelig denne måneden',
            ),
          ),
        ),
        const SizedBox(height: 20),
        _AdminMonth(
          month: _month,
          today: _today,
          availability: _availability,
          booked: _booked,
          savingDay: _savingDay,
          loading: _loadingMonth,
          canGoBack: _canMove(-1),
          canGoForward: _canMove(1),
          onMonthChanged: _changeMonth,
          onToggle: _toggle,
        ),
        if (_saveMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _saveMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onImage,
            ),
          ),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(
            _saveError!,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.busy),
          ),
        ],
      ],
    );
  }
}

class _AdminMonth extends StatelessWidget {
  const _AdminMonth({
    required this.month,
    required this.today,
    required this.availability,
    required this.booked,
    required this.savingDay,
    required this.loading,
    required this.canGoBack,
    required this.canGoForward,
    required this.onMonthChanged,
    required this.onToggle,
  });

  final DateTime month;
  final DateTime today;
  final Map<DateTime, bool> availability;
  final Set<DateTime> booked;
  final DateTime? savingDay;
  final bool loading;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final cells = monthCells(month);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: InkSurface(
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Forrige måned',
                        onPressed: canGoBack ? () => onMonthChanged(-1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          formatMonth(month),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Neste måned',
                        onPressed: canGoForward ? () => onMonthChanged(1) : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final label in calendarWeekdays)
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final cell in cells)
                        if (cell == null)
                          const SizedBox.shrink()
                        else
                          _AdminDay(
                            day: cell,
                            today: today,
                            available: availability[dateOnly(cell)],
                            booked: booked.contains(dateOnly(cell)),
                            enabled: savingDay == null,
                            onToggle: onToggle,
                          ),
                    ],
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 16),
                  const Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _LegendSwatch(color: AppColors.available, label: 'Ledig'),
                      _LegendSwatch(color: AppColors.busy, label: 'Opptatt'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color),
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

class _AdminDay extends StatelessWidget {
  const _AdminDay({
    required this.day,
    required this.today,
    required this.available,
    required this.booked,
    required this.enabled,
    required this.onToggle,
  });

  final DateTime day;
  final DateTime today;
  final bool? available;
  final bool booked;
  final bool enabled;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final past = isPastDay(day, today);
    final open = available == true;
    final blocked = available == false || booked;
    Color background = Colors.transparent;
    var foreground = AppColors.muted;
    if (open) {
      background = AppColors.available;
      foreground = Colors.white;
    } else if (blocked) {
      background = AppColors.busy;
      foreground = Colors.white;
    }
    if (past && available != null) {
      background = background.withValues(alpha: 0.45);
    }
    final status = open
        ? 'Ledig'
        : blocked
        ? 'Opptatt'
        : 'Ikke satt';

    return Semantics(
      button: true,
      label: booked
          ? '$status ${day.day}'
          : '$status ${day.day}. Klikk for å endre',
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: isSameDay(day, today) ? AppColors.ink : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: enabled && !booked ? () => onToggle(day) : null,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: isSameDay(day, today)
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
