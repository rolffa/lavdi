import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PlanTabs extends StatelessWidget {
  const PlanTabs({super.key, required this.current, required this.basePath});

  final String current;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, String)>[
      ('Kjøreplan', basePath),
      ('Hospitality', '$basePath/hospitality'),
      ('Teknisk rider', '$basePath/teknisk'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in tabs)
          tab.$1 == current
              ? FilledButton(onPressed: () {}, child: Text(tab.$1))
              : OutlinedButton(
                  onPressed: () => context.go(tab.$2),
                  child: Text(tab.$1),
                ),
      ],
    );
  }
}
