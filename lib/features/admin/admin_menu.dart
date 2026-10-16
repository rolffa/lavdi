import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class AdminMenu extends StatelessWidget {
  const AdminMenu({super.key});

  static const items = <(String, String)>[
    ('Forespørsler', '/admin'),
    ('Artister', '/admin/artister'),
    ('Kalender', '/admin/kalender'),
    ('Manuelt tilbud', '/admin/tilbud'),
  ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final current = _currentItem(path);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: item.$1 == current
                        ? Colors.white
                        : AppColors.ink,
                    backgroundColor: item.$1 == current
                        ? AppColors.ink
                        : AppColors.surface,
                    side: const BorderSide(color: AppColors.line),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.go(item.$2),
                  child: Text(item.$1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _currentItem(String path) {
  if (path.startsWith('/admin/artister')) return 'Artister';
  if (path.startsWith('/admin/kalender')) return 'Kalender';
  if (path.startsWith('/admin/tilbud')) return 'Manuelt tilbud';
  return 'Forespørsler';
}
