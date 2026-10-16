import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/stage_plot.dart';
import 'input_list_editor.dart';
import '../artist_portal/portal_widgets.dart';

class TechnicalRiderPanel extends StatelessWidget {
  const TechnicalRiderPanel({
    super.key,
    required this.leader,
    required this.busy,
    required this.plot,
    required this.inputList,
    required this.monitors,
    required this.stageRig,
    required this.paRequirements,
    required this.onSave,
    required this.onUpload,
    required this.onClear,
    required this.onDownloadPlot,
  });

  final bool leader;
  final bool busy;
  final StagePlot? plot;
  final TextEditingController inputList;
  final TextEditingController monitors;
  final TextEditingController stageRig;
  final TextEditingController paRequirements;
  final VoidCallback onSave;
  final VoidCallback onUpload;
  final VoidCallback onClear;
  final VoidCallback onDownloadPlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArtistSection(
          title: 'Scenekart',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plot == null)
                const Text('Ikke lastet opp.')
              else ...[
                Text(plot!.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (plot!.isRaster)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Image.memory(plot!.bytes, fit: BoxFit.contain),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                'PNG, JPG, SVG eller PDF. Maks 8 MB. PNG, JPG og SVG tegnes inn bakerst i den tekniske PDF-en.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (leader)
                    FilledButton(
                      onPressed: busy ? null : onUpload,
                      child: Text(
                        plot == null ? 'Last opp scenekart' : 'Last opp nytt',
                      ),
                    ),
                  if (plot != null)
                    OutlinedButton(
                      onPressed: busy ? null : onDownloadPlot,
                      child: const Text('Last ned filen'),
                    ),
                  if (leader && plot != null)
                    TextButton(
                      onPressed: busy ? null : onClear,
                      child: const Text('Fjern'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (leader) ...[
          const SizedBox(height: 20),
          InputListEditor(controller: inputList, enabled: !busy),
          const SizedBox(height: 12),
          InkSurface(
            child: TextField(
              controller: monitors,
              enabled: !busy,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Monitorbehov (wedges / IEM)',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkSurface(
            child: TextField(
              controller: stageRig,
              enabled: !busy,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'DJ / scenerigg',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkSurface(
            child: TextField(
              controller: paRequirements,
              enabled: !busy,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'PA-krav',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onSave,
              child: const Text('Lagre teknisk rider'),
            ),
          ),
        ],
      ],
    );
  }
}
