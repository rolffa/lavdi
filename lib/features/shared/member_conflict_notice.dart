import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/member_conflict.dart';

/// Warning when one or more band members are booked with another band.
class MemberConflictNotice extends StatelessWidget {
  const MemberConflictNotice({
    super.key,
    required this.conflicts,
    this.title = 'Medlem opptatt i annet band',
    this.compact = false,
    this.onImage = false,
  });

  final List<MemberDateConflict> conflicts;
  final String title;
  final bool compact;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final ink = onImage ? AppColors.onImage : AppColors.ink;
    final muted = onImage ? AppColors.onImageMuted : AppColors.muted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: onImage
            ? const Color(0x33A12E28)
            : const Color(0xFFFFF6F4),
        border: Border.all(color: AppColors.busy, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: (compact
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.titleSmall)
                  ?.copyWith(
                    color: AppColors.busy,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Denne datoen kolliderer med en bekreftet jobb i et annet band:',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 8),
            for (final conflict in conflicts) ...[
              Text(
                '• ${conflict.label}',
                style: theme.textTheme.bodyMedium?.copyWith(color: ink),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
