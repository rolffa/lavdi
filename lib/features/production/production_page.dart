import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/gig.dart';
import '../../models/production_plan.dart';
import '../riders/plan_tabs.dart';
import '../shell/portal_scaffold.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key, required this.bookingToken});

  final String bookingToken;

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  Gig? _gig;
  Object? _error;
  var _loading = true;
  var _missing = false;

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
      _missing = false;
    });
    try {
      final gig = await repository.fetchGig(widget.bookingToken);
      if (!mounted) return;
      setState(() {
        _gig = gig;
        _missing = gig == null;
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

  Future<void> _save(ProductionPlan plan) async {
    final repository = PortalScope.of(context).repository;
    final updated = await repository.saveProduction(
      bookingToken: widget.bookingToken,
      plan: plan,
    );
    if (!mounted) return;
    setState(() => _gig = updated);
  }

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const CenteredStatus(child: CircularProgressIndicator());
    }
    if (_error != null && _gig == null) {
      return ErrorRetry(message: readableError(_error!), onRetry: _load);
    }
    if (_missing || _gig == null) {
      return PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fant ingen jobb',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Lenken er ugyldig, eller kontrakten er ikke bekreftet ennå.',
            ),
          ],
        ),
      );
    }

    final gig = _gig!;
    final theme = Theme.of(context);

    return ListView(
      children: [
        PageFrame(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRODUKSJON',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.onImageMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text('Kjøreplan', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
              const SizedBox(height: 8),
              Text(
                'Fyll inn dagen slik at artisten kan hente planen i appen. Riderne hentes fra bandet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.onImageMuted,
                ),
              ),
              const SizedBox(height: 16),
              PlanTabs(
                current: 'Kjøreplan',
                basePath: '/production/${widget.bookingToken}',
              ),
              const SizedBox(height: 24),
              _JobSummary(gig: gig),
              const SizedBox(height: 28),
              _ProductionForm(
                key: const ValueKey('production-form'),
                initial: gig.production,
                onSubmit: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.gig});

  final Gig gig;

  @override
  Widget build(BuildContext context) {
    final status = gig.productionReady ? 'Kjøreplan klar' : 'Kontrakt signert';
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gig.artistName, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(formatLongDate(gig.date), style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text(
                gig.organizer.organization,
                style: theme.textTheme.titleMedium,
              ),
              Text(gig.organizer.venueCity, style: theme.textTheme.bodyMedium),
              Text(
                '${gig.organizer.contactPerson} · ${gig.organizer.email}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(status, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                'Booking ${gig.bookingId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
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

class _ProductionForm extends StatefulWidget {
  const _ProductionForm({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  final ProductionPlan initial;
  final Future<void> Function(ProductionPlan plan) onSubmit;

  @override
  State<_ProductionForm> createState() => _ProductionFormState();
}

class _ProductionFormState extends State<_ProductionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _eventName;
  late final TextEditingController _accommodationName;
  late final TextEditingController _accommodationAddress;
  late final TextEditingController _airport;
  late final TextEditingController _distance;
  late final TextEditingController _route;
  late final TextEditingController _notes;
  late final TextEditingController _dinnerVenue;
  late final TextEditingController _dinnerAddress;
  late final TextEditingController _technicianName;
  late final TextEditingController _technicianPhone;
  late TimeOfDay? _getIn;
  late TimeOfDay? _soundcheck;
  late TimeOfDay? _showGetIn;
  late TimeOfDay? _showStart;
  late TimeOfDay? _curfew;
  late TimeOfDay? _dinner;
  late TimeOfDay? _loadOut;
  late bool _dinnerAtStay;
  var _saving = false;
  var _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plan = widget.initial;
    _eventName = TextEditingController(text: plan.eventName);
    _accommodationName = TextEditingController(text: plan.accommodationName);
    _accommodationAddress = TextEditingController(
      text: plan.accommodationAddress,
    );
    _airport = TextEditingController(text: plan.nearestAirport);
    _distance = TextEditingController(text: plan.airportDistance);
    _route = TextEditingController(text: plan.travelRoute);
    _notes = TextEditingController(text: plan.notes);
    _dinnerVenue = TextEditingController(text: plan.dinnerVenueName);
    _dinnerAddress = TextEditingController(text: plan.dinnerAddress);
    _technicianName = TextEditingController(text: plan.technicianName);
    _technicianPhone = TextEditingController(text: plan.technicianPhone);
    _getIn = plan.getIn;
    _soundcheck = plan.soundcheck;
    _showGetIn = plan.showGetIn;
    _showStart = plan.showStart;
    _curfew = plan.curfew;
    _dinner = plan.dinner;
    _loadOut = plan.loadOut;
    _dinnerAtStay = plan.dinnerAtAccommodation;
    _saved = plan.eventName.isNotEmpty;
  }

  @override
  void dispose() {
    _eventName.dispose();
    _accommodationName.dispose();
    _accommodationAddress.dispose();
    _airport.dispose();
    _distance.dispose();
    _route.dispose();
    _notes.dispose();
    _dinnerVenue.dispose();
    _dinnerAddress.dispose();
    _technicianName.dispose();
    _technicianPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final plan = ProductionPlan(
      eventName: _eventName.text,
      accommodationName: _accommodationName.text,
      accommodationAddress: _accommodationAddress.text,
      nearestAirport: _airport.text,
      airportDistance: _distance.text,
      travelRoute: _route.text,
      getIn: _getIn,
      soundcheck: _soundcheck,
      showGetIn: _showGetIn,
      showStart: _showStart,
      curfew: _curfew,
      dinner: _dinner,
      loadOut: _loadOut,
      dinnerAtAccommodation: _dinnerAtStay,
      dinnerVenueName: _dinnerVenue.text,
      dinnerAddress: _dinnerAddress.text,
      technicianName: _technicianName.text,
      technicianPhone: _technicianPhone.text,
      notes: _notes.text,
    );
    try {
      await widget.onSubmit(plan);
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
    return Form(
      key: _formKey,
      child: InkSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_saved) ...[
              Text(
                'Kjøreplanen er lagret og kan hentes av artisten.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onImage,
                ),
              ),
              const SizedBox(height: 18),
            ],
            const _SectionLabel('Arrangement'),
            TextFormField(
              controller: _eventName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Arrangementsnavn / festivalnavn',
              ),
              validator: (value) =>
                  requiredField(value, 'Oppgi arrangementsnavn'),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('Reise og overnatting'),
            TextFormField(
              controller: _accommodationName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Overnattingssted'),
              validator: (value) =>
                  requiredField(value, 'Oppgi overnattingssted'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accommodationAddress,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Adresse'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _airport,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nærmeste flyplass'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _distance,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Avstand fra flyplass til spillested',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _route,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Mer info'),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('Tider'),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                return Column(
                  children: [
                    _pair(
                      wide: wide,
                      first: _timeField(
                        label: 'Get-in',
                        value: _getIn,
                        onChanged: (value) => setState(() => _getIn = value),
                      ),
                      second: _timeField(
                        label: 'Lydprøve',
                        value: _soundcheck,
                        onChanged: (value) =>
                            setState(() => _soundcheck = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      wide: wide,
                      first: _timeField(
                        label: 'Get-in show',
                        helper: 'Når artist og band skal være på plass.',
                        value: _showGetIn,
                        onChanged: (value) =>
                            setState(() => _showGetIn = value),
                      ),
                      second: _timeField(
                        label: 'Showstart',
                        value: _showStart,
                        onChanged: (value) =>
                            setState(() => _showStart = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      wide: wide,
                      first: _timeField(
                        label: 'Curfew',
                        value: _curfew,
                        onChanged: (value) => setState(() => _curfew = value),
                      ),
                      second: _timeField(
                        label: 'Middag',
                        mandatory: false,
                        value: _dinner,
                        onChanged: (value) => setState(() => _dinner = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      wide: wide,
                      first: _timeField(
                        label: 'Load-out',
                        mandatory: false,
                        value: _loadOut,
                        onChanged: (value) => setState(() => _loadOut = value),
                      ),
                      second: const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            const _SectionLabel('Middag'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('På overnattingssted'),
              value: _dinnerAtStay,
              onChanged: (value) => setState(() => _dinnerAtStay = value),
            ),
            if (!_dinnerAtStay) ...[
              TextFormField(
                controller: _dinnerVenue,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Restaurant'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dinnerAddress,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
            ],
            const SizedBox(height: 28),
            const _SectionLabel('Tekniker'),
            TextFormField(
              controller: _technicianName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Teknisk ansvarlig'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _technicianPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('Merknader'),
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Merknader til artist / band',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.busy,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Lagrer…' : 'Lagre kjøreplan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay?> onChanged,
    String? helper,
    bool mandatory = true,
  }) {
    return FormField<TimeOfDay>(
      initialValue: value,
      validator: (current) =>
          mandatory ? clockField(current, 'Velg tid') : null,
      builder: (state) {
        final shown = state.value;
        return InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: shown ?? const TimeOfDay(hour: 16, minute: 0),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
            if (picked == null) return;
            state.didChange(picked);
            onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperStyle: const TextStyle(color: AppColors.muted),
              errorText: state.errorText,
            ),
            isEmpty: shown == null,
            child: Text(shown == null ? '' : formatClock(shown)),
          ),
        );
      },
    );
  }

  Widget _pair({
    required bool wide,
    required Widget first,
    required Widget second,
  }) {
    if (!wide) {
      return Column(children: [first, const SizedBox(height: 12), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: AppColors.onImageMuted),
      ),
    );
  }
}
