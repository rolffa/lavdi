import 'package:flutter/material.dart';

import '../../core/rider_export.dart';
import '../../core/theme.dart';

class RiderExportMenu extends StatelessWidget {
  const RiderExportMenu({
    super.key,
    required this.busy,
    required this.onExport,
  });

  final bool busy;
  final ValueChanged<RiderExport> onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: busy ? null : () => onExport(RiderExport.complete),
          child: const Text('Last ned komplett Rider (PDF)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : () => onExport(RiderExport.technical),
          child: const Text('Kun Teknisk Rider (m/ scenekart)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : () => onExport(RiderExport.hospitality),
          child: const Text('Kun Hospitality Rider'),
        ),
      ],
    );
  }
}

Future<bool> confirmRiderGaps(
  BuildContext context,
  List<ProfileGap> gaps,
) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return InkSurface(
        child: AlertDialog(
          title: const Text('Profiler er ikke ferdige'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dietter, telefon og tekniske behov hentes fra medlemsprofilene. Du kan fylle dem ut først, eller generere PDF-en likevel.',
              ),
              const SizedBox(height: 12),
              for (final gap in gaps) Text(gap.sentence),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generer likevel'),
            ),
          ],
        ),
      );
    },
  );
  return proceed == true;
}
