import 'package:flutter/material.dart';

import '../../core/theme.dart';

class LeaderMailCard extends StatelessWidget {
  const LeaderMailCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: InkSurface(
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final heading = theme.textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
            );
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Varsler', style: heading),
                  const SizedBox(height: 6),
                  Text(
                    'Alle varsler sendes til alle bandmedlemmer.',
                    style: theme.textTheme.bodyMedium?.copyWith(
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

bool showPushCard({required bool isLeader, required String role}) {
  return true;
}
