import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class ArtistFrame extends StatelessWidget {
  const ArtistFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width < 720 ? 16 : 24,
            20,
            width < 720 ? 16 : 24,
            40,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ArtistBackButton extends StatelessWidget {
  const ArtistBackButton({super.key, required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.go(path),
        icon: const Icon(Icons.arrow_back),
        label: Text(label),
      ),
    );
  }
}

class ArtistSection extends StatelessWidget {
  const ArtistSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: InkSurface(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
    if (onTap == null) return box;
    return InkWell(onTap: onTap, child: box);
  }
}
