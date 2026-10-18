import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../core/venue_match.dart';
import '../../models/venue_note.dart';
import 'portal_widgets.dart';

class VenueNotesSection extends StatefulWidget {
  const VenueNotesSection({
    super.key,
    required this.venueLabel,
    required this.gigDate,
  });

  final String venueLabel;
  final DateTime gigDate;

  @override
  State<VenueNotesSection> createState() => _VenueNotesSectionState();
}

class _VenueNotesSectionState extends State<VenueNotesSection> {
  final _venue = TextEditingController();
  final _city = TextEditingController();
  final _loadIn = TextEditingController();
  final _sound = TextEditingController();
  final _hospitality = TextEditingController();
  final _contact = TextEditingController();
  List<VenueNote> _notes = const [];
  var _loading = true;
  var _writing = false;
  var _saving = false;
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
    _venue.dispose();
    _city.dispose();
    _loadIn.dispose();
    _sound.dispose();
    _hospitality.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final notes = await PortalScope.of(context).repository.fetchVenueNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes
            .where((note) => venueNoteMatches(note, widget.venueLabel))
            .toList();
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

  void _openForm() {
    final place = splitVenueLabel(widget.venueLabel);
    if (_venue.text.trim().isEmpty) _venue.text = place.name;
    if (_city.text.trim().isEmpty) _city.text = place.city;
    setState(() {
      _writing = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PortalScope.of(context).repository.addVenueNote(
        venueName: _venue.text,
        city: _city.text,
        loadInNotes: _loadIn.text,
        soundLightingNotes: _sound.text,
        hospitalityNotes: _hospitality.text,
        contactNotes: _contact.text,
      );
      _loadIn.clear();
      _sound.clear();
      _hospitality.clear();
      _contact.clear();
      if (!mounted) return;
      setState(() => _writing = false);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = gigDayHasEnded(widget.gigDate, DateTime.now());
    if (_loading) {
      return const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (!finished && _notes.isEmpty && _error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: ArtistSection(
        title: 'Spillested',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_notes.isNotEmpty)
              for (final note in _notes) ...[
                _NoteCard(note: note),
                const SizedBox(height: 12),
              ],
            if (finished && !_writing)
              FilledButton(
                onPressed: _openForm,
                child: const Text('Legg til erfaringer fra spillestedet'),
              ),
            if (_writing) ...[
              Text(
                'Erfaringer fra spillestedet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _Field(controller: _venue, label: 'Spillested'),
              _Field(controller: _city, label: 'By'),
              _Field(
                controller: _loadIn,
                label: 'Bæring, heis og trapper',
                lines: 3,
              ),
              _Field(
                controller: _sound,
                label: 'Lyd, lys og tekniker',
                lines: 3,
              ),
              _Field(
                controller: _hospitality,
                label: 'Mat, garderobe og vertskap',
                lines: 3,
              ),
              _Field(controller: _contact, label: 'Kontaktpersoner', lines: 3),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Lagre notat'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.busy,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final VenueNote note;

  @override
  Widget build(BuildContext context) {
    final place = [
      note.venueName,
      if (note.city.isNotEmpty) note.city,
    ].join(', ');
    return ArtistCard(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              _Line(label: 'Bæring', value: note.loadInNotes),
              _Line(label: 'Lyd og lys', value: note.soundLightingNotes),
              _Line(label: 'Hospitality', value: note.hospitalityNotes),
              _Line(label: 'Kontakt', value: note.contactNotes),
            ],
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: AppColors.muted),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.lines = 1});

  final TextEditingController controller;
  final String label;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkSurface(
        child: TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines,
          style: portalFieldStyle,
          cursorColor: AppColors.ink,
          decoration: fieldDecoration(label: label),
        ),
      ),
    );
  }
}
