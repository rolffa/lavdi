import 'package:flutter/material.dart';

import '../../core/deal_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/booking_deal.dart';
import '../../models/gig.dart';
import '../travel/travel_section.dart';
import 'portal_widgets.dart';

class CrewTravelSection extends StatefulWidget {
  const CrewTravelSection({super.key, required this.gig});

  final Gig gig;

  @override
  State<CrewTravelSection> createState() => _CrewTravelSectionState();
}

class _CrewTravelSectionState extends State<CrewTravelSection> {
  List<CrewLeg> _crew = const [];
  var _loading = true;
  String? _error;
  var _leader = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final repository = PortalScope.of(context).repository;
      final band = await repository.fetchMyBand();
      final crew = await repository.fetchCrewTravel(widget.gig.id);
      if (!mounted) return;
      setState(() {
        _leader = band?.me.isLeader ?? false;
        _crew = crew;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = readableError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const LinearProgressIndicator();
    if (_error != null) return Text(_error!);
    if (_crew.isEmpty) return const SizedBox.shrink();
    final complete = crewTravelComplete(_crew);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          complete
              ? 'Alle som skal være med har huket av for reise bestilt. PDF-en ligger klar hos admin.'
              : 'Når flyreisen er bestilt, fyll inn tidene og huk av. Infoen sendes som PDF til arrangøren når alle aktive medlemmer er ferdige.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
        ),
        const SizedBox(height: 12),
        for (final leg in _crew) ...[
          _CrewCard(
            gig: widget.gig,
            leg: leg,
            leader: _leader,
            onChanged: (crew) => setState(() => _crew = crew),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CrewCard extends StatefulWidget {
  const _CrewCard({
    required this.gig,
    required this.leg,
    required this.leader,
    required this.onChanged,
  });

  final Gig gig;
  final CrewLeg leg;
  final bool leader;
  final ValueChanged<List<CrewLeg>> onChanged;

  @override
  State<_CrewCard> createState() => _CrewCardState();
}

class _CrewCardState extends State<_CrewCard> {
  late final TextEditingController _pickup;
  late final TextEditingController _dropoff;
  DateTime? _arrivalDate;
  TimeOfDay? _arrivalTime;
  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final leg = widget.leg;
    _pickup = TextEditingController(text: leg.pickup);
    _dropoff = TextEditingController(text: leg.dropoff);
    _arrivalDate = leg.arrival == null ? null : dateOnly(leg.arrival!.toLocal());
    _arrivalTime = leg.arrival == null ? null : TimeOfDay.fromDateTime(leg.arrival!.toLocal());
    _departureDate = leg.departure == null ? null : dateOnly(leg.departure!.toLocal());
    _departureTime = leg.departure == null
        ? null
        : TimeOfDay.fromDateTime(leg.departure!.toLocal());
  }

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  Future<void> _setActive(bool active) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final crew = await PortalScope.of(context).repository.setCrewMemberActive(
        gigId: widget.gig.id,
        memberId: widget.leg.memberId,
        active: active,
      );
      if (!mounted) return;
      widget.onChanged(crew);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _book() async {
    final arrivalDate = _arrivalDate;
    final arrivalTime = _arrivalTime;
    final departureDate = _departureDate;
    final departureTime = _departureTime;
    if (arrivalDate == null ||
        arrivalTime == null ||
        departureDate == null ||
        departureTime == null ||
        _pickup.text.trim().isEmpty ||
        _dropoff.text.trim().isEmpty) {
      setState(() => _error = 'Ankomst, hentested, avreise og avleveringssted må fylles ut.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final crew = await PortalScope.of(context).repository.saveCrewTravel(
        gigId: widget.gig.id,
        memberId: widget.leg.memberId,
        arrival: DateTime(
          arrivalDate.year,
          arrivalDate.month,
          arrivalDate.day,
          arrivalTime.hour,
          arrivalTime.minute,
        ),
        departure: DateTime(
          departureDate.year,
          departureDate.month,
          departureDate.day,
          departureTime.hour,
          departureTime.minute,
        ),
        pickup: _pickup.text,
        dropoff: _dropoff.text,
      );
      if (!mounted) return;
      widget.onChanged(crew);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leg = widget.leg;
    return ArtistCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leg.name,
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink),
          ),
          Text(leg.role),
          if (widget.leader)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Med på denne konserten'),
              value: leg.active,
              onChanged: _busy ? null : _setActive,
            ),
          if (!leg.active)
            const Text('Ikke med på denne konserten.')
          else ...[
            if (leg.booked)
              Text(
                'Reise bestilt',
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.available),
              ),
            const SizedBox(height: 8),
            MomentField(
              dateLabel: 'Ankomst',
              timeLabel: 'Klokkeslett',
              date: _arrivalDate,
              time: _arrivalTime,
              firstDate: DateTime(widget.gig.date.year - 1),
              lastDate: DateTime(widget.gig.date.year + 2),
              fallbackDate: widget.gig.date,
              onDate: (value) => setState(() => _arrivalDate = value),
              onTime: (value) => setState(() => _arrivalTime = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pickup,
              decoration: const InputDecoration(labelText: 'Hentested'),
            ),
            const SizedBox(height: 12),
            MomentField(
              dateLabel: 'Avreise',
              timeLabel: 'Klokkeslett',
              date: _departureDate,
              time: _departureTime,
              firstDate: DateTime(widget.gig.date.year - 1),
              lastDate: DateTime(widget.gig.date.year + 2),
              fallbackDate: widget.gig.date,
              onDate: (value) => setState(() => _departureDate = value),
              onTime: (value) => setState(() => _departureTime = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dropoff,
              decoration: const InputDecoration(labelText: 'Avleveringssted'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _book,
              child: Text(_busy ? 'Lagrer…' : 'Reise bestilt'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!),
          ],
        ],
      ),
    );
  }
}
