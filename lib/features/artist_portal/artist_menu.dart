import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'band_switcher_bar.dart';

class ArtistMenu extends StatelessWidget {
  const ArtistMenu({super.key});

  static const items = <(String, String)>[
    ('Konserter', '/min-side'),
    ('Band/crew', '/min-side/band'),
    ('Settliste', '/min-side/settliste'),
    ('Ridere', '/min-side/ridere'),
    ('Kalender', '/min-side/kalender'),
    ('Presse', '/artist/presse'),
    ('Konto', '/min-side/konto'),
  ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final current = _currentItem(path);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
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
                    _MenuButton(
                      label: item.$1,
                      selected: item.$1 == current,
                      onPressed: () => context.go(item.$2),
                    ),
                ],
              ),
            ),
          ),
        ),
        const BandSwitcherBar(),
      ],
    );
  }
}

String _currentItem(String path) {
  if (path.contains('/presse')) return 'Presse';
  if (path.contains('/settliste') || path.contains('/repertoar')) {
    return 'Settliste';
  }
  if (path.contains('/ridere') ||
      path.contains('/hospitality') ||
      path.contains('/teknisk')) {
    return 'Ridere';
  }
  if (path.startsWith('/min-side/kalender')) return 'Kalender';
  if (path.startsWith('/min-side/konto')) return 'Konto';
  if (path.startsWith('/min-side/band') ||
      path.startsWith('/min-side/profil')) {
    return 'Band/crew';
  }
  return 'Konserter';
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.white : AppColors.ink,
        backgroundColor: selected ? AppColors.ink : AppColors.surface,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
