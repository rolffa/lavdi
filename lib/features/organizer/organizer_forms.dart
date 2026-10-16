import 'package:flutter/material.dart';

import '../../core/deal_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/booking_deal.dart';
import '../shell/portal_scaffold.dart';

class OrganizerTravelPage extends StatefulWidget {
  const OrganizerTravelPage({super.key, required this.token});

  final String token;

  @override
  State<OrganizerTravelPage> createState() => _OrganizerTravelPageState();
}

class _OrganizerTravelPageState extends State<OrganizerTravelPage> {
  final _airport = TextEditingController();
  final _distance = TextEditingController();
  final _route = TextEditingController();
  BookingDeal? _deal;
  var _loading = true;
  var _saving = false;
  var _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _airport.dispose();
    _distance.dispose();
    _route.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final deal =
          await PortalScope.of(context).repository.fetchDealByTravelToken(widget.token);
      if (!mounted) return;
      _airport.text = deal?.airport ?? '';
      _distance.text = deal?.airportDistance ?? '';
      _route.text = deal?.route ?? '';
      setState(() {
        _deal = deal;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = readableError(error);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_airport.text.trim().isEmpty || _distance.text.trim().isEmpty) {
      setState(() => _error = 'Flyplass og avstand må fylles ut');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PortalScope.of(context).repository.saveOrganizerTravel(
        token: widget.token,
        airport: _airport.text,
        distance: _distance.text,
        route: _route.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deal = _deal;
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 720,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : deal == null
                ? Text(
                    _error ?? 'Fant ikke skjemaet.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
                  )
                : DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
                    ),
                    child: InkSurface(
                      child: Builder(
                        builder: (context) {
                          final theme = Theme.of(context);
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reise til konserten',
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text('${deal.artistName} · ${formatLongDate(deal.date)}'),
                                Text(deal.venue),
                                const SizedBox(height: 8),
                                const Text(
                                  'Fyll ut nærmeste flyplass og avstand til spillestedet, så artisten kan bestille reise. Bruk mer info hvis reiseveien trenger ekstra forklaring.',
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _airport,
                                  decoration: const InputDecoration(
                                    labelText: 'Nærmeste flyplass',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _distance,
                                  decoration: const InputDecoration(
                                    labelText: 'Avstand fra flyplass til spillested',
                                    hintText: 'F.eks. 35 km / 40 minutter',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _route,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Mer info',
                                    hintText:
                                        'Valgfritt – forklar reiseveien hvis den ikke er rett frem',
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(_error!),
                                ],
                                if (_saved) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Sendt inn. Artisten får beskjed om å bestille reise.',
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child: Text(_saving ? 'Sender…' : 'Send inn'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class OrganizerDayPage extends StatefulWidget {
  const OrganizerDayPage({super.key, required this.token});

  final String token;

  @override
  State<OrganizerDayPage> createState() => _OrganizerDayPageState();
}

class _OrganizerDayPageState extends State<OrganizerDayPage> {
  final _dinner = TextEditingController();
  final _hotelName = TextEditingController();
  final _hotelAddress = TextEditingController();
  final _notes = TextEditingController();
  BookingDeal? _deal;
  TimeOfDay? _getIn;
  TimeOfDay? _soundcheck;
  TimeOfDay? _show;
  var _loading = true;
  var _saving = false;
  var _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _dinner.dispose();
    _hotelName.dispose();
    _hotelAddress.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final deal =
          await PortalScope.of(context).repository.fetchDealByDayToken(widget.token);
      if (!mounted) return;
      _dinner.text = deal?.dinnerPlace ?? '';
      _hotelName.text = deal?.hotelName ?? '';
      _hotelAddress.text = deal?.hotelAddress ?? '';
      _notes.text = deal?.dayNotes ?? '';
      setState(() {
        _deal = deal;
        _getIn = deal?.getIn;
        _soundcheck = deal?.soundcheck;
        _show = deal?.showStart;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = readableError(error);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final getIn = _getIn;
    final soundcheck = _soundcheck;
    final show = _show;
    if (getIn == null ||
        soundcheck == null ||
        show == null ||
        _hotelAddress.text.trim().isEmpty) {
      setState(
        () => _error = 'Get-in, lydprøve, showstart og hotelladresse må fylles ut',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PortalScope.of(context).repository.saveOrganizerDay(
        token: widget.token,
        getIn: getIn,
        soundcheck: soundcheck,
        showStart: show,
        dinnerPlace: _dinner.text,
        hotelName: _hotelName.text,
        hotelAddress: _hotelAddress.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deal = _deal;
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 720,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : deal == null
                ? Text(
                    _error ?? 'Fant ikke skjemaet.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
                  )
                : DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
                    ),
                    child: InkSurface(
                      child: Builder(
                        builder: (context) {
                          final theme = Theme.of(context);
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dagen', style: theme.textTheme.headlineSmall),
                                const SizedBox(height: 8),
                                Text('${deal.artistName} · ${formatLongDate(deal.date)}'),
                                Text(deal.venue),
                                const SizedBox(height: 8),
                                Text(
                                  'Frist for skjemaet er ${formatLongDate(daySheetDue(deal.date))}.',
                                ),
                                const SizedBox(height: 16),
                                _Clock(
                                  label: 'Get-in',
                                  time: _getIn,
                                  onPick: (value) => setState(() => _getIn = value),
                                ),
                                _Clock(
                                  label: 'Lydprøve',
                                  time: _soundcheck,
                                  onPick: (value) => setState(() => _soundcheck = value),
                                ),
                                _Clock(
                                  label: 'Showstart',
                                  time: _show,
                                  onPick: (value) => setState(() => _show = value),
                                ),
                                TextField(
                                  controller: _dinner,
                                  decoration: const InputDecoration(labelText: 'Middagssted'),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _hotelName,
                                  decoration: const InputDecoration(
                                    labelText: 'Overnattingssted',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _hotelAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Adresse for overnatting',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _notes,
                                  minLines: 3,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Andre detaljer om dagen',
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(_error!),
                                ],
                                if (_saved) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Lagret. Artisten får tidslinje og det som er i nærheten av hotellet.',
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child: Text(_saving ? 'Lagrer…' : 'Lagre dagskjema'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.label, required this.time, required this.onPick});

  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 16, minute: 0),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
          if (picked != null) onPick(picked);
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label: ${time == null ? 'Velg klokkeslett' : formatClock(time!)}'),
        ),
      ),
    );
  }
}
