import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/input_list.dart';
import '../../core/rider_text.dart';
import '../../core/theme.dart';
import '../../models/band.dart';
import '../artist_portal/portal_widgets.dart';

class RiderView extends StatefulWidget {
  const RiderView({
    super.key,
    required this.kind,
    required this.band,
    required this.members,
  });

  final RiderKind kind;
  final Band band;
  final List<BandMember> members;

  @override
  State<RiderView> createState() => _RiderViewState();
}

class _RiderViewState extends State<RiderView> {
  var _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = formatRider(widget.kind, widget.band, widget.members);
    final hospitality = widget.kind == RiderKind.hospitality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hospitality
              ? 'Samlet fra medlemmenes mat, allergier og bandets backstage- og losjiinfo.'
              : 'Samlet fra bandets tekniske oppsett og medlemmenes personlige behov.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!mounted) return;
            setState(() => _copied = true);
          },
          child: Text(_copied ? 'Kopiert' : 'Kopier rider'),
        ),
        const SizedBox(height: 20),
        if (hospitality) ...[
          ArtistSection(
            title: 'Kontakt',
            child: Text(
              widget.band.contact.isEmpty ? 'Ikke satt' : widget.band.contact,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 20),
          ArtistSection(
            title: 'Backstage og losji',
            child: Text(
              widget.band.sharedHospitality.isEmpty
                  ? 'Ikke satt'
                  : widget.band.sharedHospitality,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 20),
          ArtistSection(
            title: 'Mat, dietter og allergier',
            child: _People(
              members: widget.members,
              detailLabel: 'Mat',
              line: (member) =>
                  member.food.isEmpty ? 'Ikke utfylt' : member.food,
              showPhone: true,
            ),
          ),
        ] else ...[
          ArtistSection(
            title: 'Inputliste / patch',
            child: _InputListPreview(stored: widget.band.inputList),
          ),
          const SizedBox(height: 20),
          for (final section in [
            ('Monitorbehov', widget.band.monitors),
            ('DJ / scenerigg', widget.band.stageRig),
            ('PA-krav', widget.band.paRequirements),
            ('Felles teknisk oppsett', widget.band.sharedTech),
          ]) ...[
            ArtistSection(
              title: section.$1,
              child: Text(
                section.$2.isEmpty ? 'Ikke satt' : section.$2,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
          ],
          ArtistSection(
            title: 'Scenekart',
            child: Text(
              widget.band.stagePlotName.isEmpty
                  ? 'Ikke lastet opp'
                  : widget.band.stagePlotName,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 20),
          ArtistSection(
            title: 'Personlige tekniske behov',
            child: _People(
              members: widget.members,
              detailLabel: 'Personlig teknikk',
              line: (member) => member.personalTech.isEmpty
                  ? 'Ikke utfylt'
                  : member.personalTech,
            ),
          ),
        ],
      ],
    );
  }
}

class _InputListPreview extends StatelessWidget {
  const _InputListPreview({required this.stored});

  final String stored;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = filledInputChannels(stored);
    if (rows.isEmpty) {
      return Text('Ikke satt', style: theme.textTheme.bodyLarge);
    }
    final onRow = theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink);
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            color: index.isOdd ? AppColors.paperDeep : AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ch ${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rows[index].source.isEmpty ? '—' : rows[index].source,
                  style: onRow,
                ),
                if (rows[index].mic.isNotEmpty)
                  Text('Mic / DI: ${rows[index].mic}', style: onRow),
                if (rows[index].stand.isNotEmpty)
                  Text('Stand: ${rows[index].stand}', style: onRow),
                if (rows[index].notes.isNotEmpty)
                  Text('Notes / 48V: ${rows[index].notes}', style: onRow),
              ],
            ),
          ),
      ],
    );
  }
}

class _People extends StatelessWidget {
  const _People({
    required this.members,
    required this.detailLabel,
    required this.line,
    this.showPhone = false,
  });

  final List<BandMember> members;
  final String detailLabel;
  final String Function(BandMember member) line;
  final bool showPhone;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'Ingen profiler er utfylt ennå.',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    final people = List<BandMember>.of(members)
      ..sort((a, b) {
        if (a.isLeader != b.isLeader) return a.isLeader ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final member in people) ...[
            ArtistCard(
              child: _MemberEntry(
                member: member,
                detailLabel: detailLabel,
                detail: line(member),
                showPhone: showPhone,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MemberEntry extends StatelessWidget {
  const _MemberEntry({
    required this.member,
    required this.detailLabel,
    required this.detail,
    required this.showPhone,
  });

  final BandMember member;
  final String detailLabel;
  final String detail;
  final bool showPhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member.name.trim().isEmpty ? 'Uten navn' : member.name.trim();
    final role = member.role.trim().isEmpty
        ? 'Rolle ikke satt'
        : member.role.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          role,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        if (showPhone) ...[
          _LabeledLine(
            label: 'Telefon',
            value: member.phone.trim().isEmpty
                ? 'Ikke satt'
                : member.phone.trim(),
          ),
          const SizedBox(height: 12),
        ],
        _LabeledLine(label: detailLabel, value: detail),
      ],
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}
