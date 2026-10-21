import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/maps_links.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/gig.dart';
import '../../models/production_plan.dart';
import '../../web/external_link.dart';
import '../../web/rider_files.dart';
import '../shell/portal_scaffold.dart';
import 'member_travel_section.dart';
import 'portal_widgets.dart';
import 'venue_notes_section.dart';

class GigDashboardPage extends StatefulWidget {
  const GigDashboardPage({super.key, required this.gigId});

  final String gigId;

  @override
  State<GigDashboardPage> createState() => _GigDashboardPageState();
}

class _GigDashboardPageState extends State<GigDashboardPage> {
  Gig? _gig;
  Object? _error;
  var _loading = true;
  var _contractBusy = false;
  String? _contractError;

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
      _contractError = null;
    });
    try {
      final session = await repository.currentArtist();
      if (session == null) {
        if (!mounted) return;
        setState(() {
          _gig = null;
          _loading = false;
        });
        return;
      }
      final gigs = await repository.fetchMyGigs();
      if (!mounted) return;
      setState(() {
        _gig = gigs.where((gig) => gig.id == widget.gigId).firstOrNull;
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

  Future<void> _downloadContract() async {
    final gig = _gig;
    if (gig == null) return;
    setState(() {
      _contractBusy = true;
      _contractError = null;
    });
    try {
      final bytes = await PortalScope.of(context)
          .repository
          .downloadContractPdfForGig(gig.id);
      if (!mounted) return;
      final stamp = formatIsoDate(gig.date);
      final safeArtist = gig.artistName.trim().isEmpty
          ? 'artist'
          : gig.artistName.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
      saveBytes(
        Uint8List.fromList(bytes),
        'kontrakt-$safeArtist-$stamp.pdf',
        'application/pdf',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _contractError = readableError(error));
    } finally {
      if (mounted) setState(() => _contractBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(children: [ArtistFrame(child: _body(context))]),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return ErrorRetry(message: readableError(_error!), onRetry: _load);
    }
    final gig = _gig;
    if (gig == null) {
      return const Text('Fant ikke konserten, eller du er logget ut.');
    }
    final theme = Theme.of(context);
    final plan = gig.production;
    final title = plan.eventName.trim().isEmpty
        ? gig.organizer.venueCity
        : plan.eventName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
        const SizedBox(height: 4),
        Text(
          formatLongDate(gig.date),
          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.onImage),
        ),
        if (gig.organizer.venueCity.trim().isNotEmpty &&
            gig.organizer.venueCity.trim() != title)
          Text(gig.organizer.venueCity),
        const SizedBox(height: 20),
        ArtistSection(
          title: 'Kontrakt',
          child: ArtistCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konsertkontrakt generert fra forespørselen. '
                  'Last ned for manuell signering.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                if (_contractError != null) ...[
                  const SizedBox(height: 8),
                  FieldError(_contractError!),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _contractBusy ? null : _downloadContract,
                  child: Text(
                    _contractBusy ? 'Henter…' : 'Last ned kontrakt (PDF)',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        VenueNotesSection(
          venueLabel: gig.organizer.venueCity,
          gigDate: gig.date,
        ),
        ArtistSection(
          title: 'Tidslinje',
          child: _Timeline(plan: plan),
        ),
        const SizedBox(height: 28),
        ArtistSection(
          title: 'Reise og logistikk',
          child: ArtistCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nærmeste flyplass',
                  style: theme.textTheme.labelLarge?.copyWith(color: AppColors.ink),
                ),
                Text(
                  plan.nearestAirport.isEmpty
                      ? 'Ikke satt'
                      : plan.nearestAirport,
                ),
                const SizedBox(height: 12),
                Text(
                  'Avstand til spillested',
                  style: theme.textTheme.labelLarge?.copyWith(color: AppColors.ink),
                ),
                Text(
                  plan.airportDistance.isEmpty
                      ? 'Ikke satt'
                      : plan.airportDistance,
                ),
                if (plan.travelRoute.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Mer info',
                    style: theme.textTheme.labelLarge?.copyWith(color: AppColors.ink),
                  ),
                  Text(plan.travelRoute),
                ],
                const SizedBox(height: 16),
                _Contact(
                  role: 'Arrangør',
                  name: gig.organizer.contactPerson,
                  detail: gig.organizer.organization,
                  phone: gig.organizer.phone,
                ),
                const SizedBox(height: 12),
                _Contact(
                  role: 'Teknisk ansvarlig',
                  name: plan.technicianName,
                  detail: '',
                  phone: plan.technicianPhone,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ArtistSection(
          title: 'Reise bestilt',
          child: plan.travelBriefReady
              ? CrewTravelSection(gig: gig)
              : ArtistCard(
                  child: Text(
                    'Venter på at arrangøren fyller ut flyplass og avstand. Da får du beskjed om å bestille reise.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.ink),
                  ),
                ),
        ),
        const SizedBox(height: 28),
        ArtistSection(
          title: 'Overnatting',
          child: ArtistCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.accommodationName.isEmpty
                      ? 'Ikke satt'
                      : plan.accommodationName,
                  style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink),
                ),
                if (plan.accommodationAddress.isNotEmpty)
                  Text(plan.accommodationAddress),
                if (plan.daySheetReady && plan.accommodationAddress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _LinkButton(
                    label: 'Veibeskrivelse i Google Maps',
                    url: mapsDirectionsUrl(plan.accommodationAddress),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'I nærheten av hotell',
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  for (final place in nearbyPlaces) ...[
                    _LinkButton(
                      label: place.$1,
                      url: mapsNearbyUrl(
                        address: plan.accommodationAddress,
                        place: place.$2,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ArtistSection(
          title: 'Middag',
          child: _Dinner(plan: plan),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.plan});

  final ProductionPlan plan;

  @override
  Widget build(BuildContext context) {
    final dinnerDetail =
        plan.dinnerAtAccommodation || plan.dinnerVenueName.trim().isEmpty
        ? 'På overnattingssted'
        : plan.dinnerVenueName;
    final rows = [
      ('Get-in', plan.getIn, ''),
      ('Lydprøve', plan.soundcheck, ''),
      ('Get-in show', plan.showGetIn, ''),
      ('Middag', plan.dinner, dinnerDetail),
      ('Showstart', plan.showStart, ''),
      ('Load-out', plan.loadOut, ''),
    ];
    return ArtistCard(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            _TimelineRow(
              label: rows[index].$1,
              time: rows[index].$2,
              detail: rows[index].$3,
              last: index == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.detail,
    required this.last,
  });

  final String label;
  final TimeOfDay? time;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              time == null ? '–' : formatClock(time!),
              style: theme.textTheme.titleMedium,
            ),
          ),
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
              if (!last)
                const Expanded(
                  child: SizedBox(
                    width: 1,
                    child: ColoredBox(color: AppColors.line),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({
    required this.role,
    required this.name,
    required this.detail,
    required this.phone,
  });

  final String role;
  final String name;
  final String detail;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role, style: Theme.of(context).textTheme.labelLarge),
        Text(name.isEmpty ? 'Ikke satt' : name),
        if (detail.isNotEmpty) Text(detail),
        if (digits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => openExternal('tel:$digits'),
                child: const Text('Ring'),
              ),
              OutlinedButton(
                onPressed: () => openExternal('sms:$digits'),
                child: const Text('SMS'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Dinner extends StatelessWidget {
  const _Dinner({required this.plan});

  final ProductionPlan plan;

  @override
  Widget build(BuildContext context) {
    final atStay =
        plan.dinnerAtAccommodation || plan.dinnerVenueName.trim().isEmpty;
    return ArtistCard(
      child: atStay
          ? Text(
              'På overnattingssted',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.dinnerVenueName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                if (plan.dinnerAddress.isNotEmpty) Text(plan.dinnerAddress),
                if (plan.dinnerAddress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _LinkButton(
                    label: 'Veibeskrivelse i Google Maps',
                    url: mapsDirectionsUrl(plan.dinnerAddress),
                  ),
                ],
              ],
            ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => openExternal(url),
        child: Text(label),
      ),
    );
  }
}
