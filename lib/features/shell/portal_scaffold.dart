import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist_session.dart';
import '../admin/admin_menu.dart';
import '../artist_portal/artist_menu.dart';

class PortalScaffold extends StatelessWidget {
  const PortalScaffold({
    super.key,
    required this.body,
    this.artistMenu = false,
  });

  final Widget body;
  final bool artistMenu;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context);
    final image = onImageTheme(ink);
    final path = GoRouterState.of(context).uri.path;
    final showAdminMenu = path == '/admin' || path.startsWith('/admin/');
    final adminView = PortalScope.of(context).repository.adminViewAsArtist;
    final showAdminViewBanner = adminView != null &&
        (artistMenu ||
            path.startsWith('/min-side') ||
            path == '/artist/presse');
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          image: DecorationImage(
            image: AssetImage('assets/brand/Bakgrunn3.jpeg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: Column(
          children: [
            const PortalHeader(),
            if (showAdminViewBanner) AdminArtistViewBanner(session: adminView),
            if (artistMenu) const ArtistMenu(),
            if (showAdminMenu) const AdminMenu(),
            Expanded(
              child: OnImageThemeScope(
                ink: ink,
                child: Theme(
                  data: image,
                  child: DefaultTextStyle(
                    style:
                        image.textTheme.bodyMedium ??
                        const TextStyle(color: AppColors.onImage),
                    child: body,
                  ),
                ),
              ),
            ),
            const PortalFooter(),
          ],
        ),
      ),
    );
  }
}

class PortalFooter extends StatelessWidget {
  const PortalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Text(
        'Amundsen Studio © 2026',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.onImageMuted,
        ),
      ),
    );
  }
}

class PortalHeader extends StatelessWidget {
  const PortalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 720 ? 20.0 : 32.0;
    final theme = Theme.of(context);
    final path = GoRouterState.of(context).uri.path;

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          SizedBox(
              height: width < 720 ? 108 : 132,
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const aspect = 2752 / 503;
                    final narrow = width < 720;
                    final maxHeight = narrow ? 72.0 : 108.0;
                    final reserved = narrow ? 210.0 : 300.0;
                    var logoHeight = maxHeight;
                    var logoWidth = logoHeight * aspect;
                    final available =
                        constraints.maxWidth -
                        (narrow ? reserved : reserved * 2);
                    if (logoWidth > available && available > 0) {
                      logoWidth = available;
                      logoHeight = logoWidth / aspect;
                    }
                    final logo = InkWell(
                      onTap: () => context.go('/'),
                      child: Semantics(
                        button: true,
                        label: Brand.name,
                        child: Image.asset(
                          'assets/brand/logo2.png',
                          width: logoWidth,
                          height: logoHeight,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    );
                    final onArtistPortal =
                        path.startsWith('/min-side') ||
                        path.startsWith('/artist/foresporsler') ||
                        path.startsWith('/artist/gigs') ||
                        path.startsWith('/artist/presse');
                    final onAdmin =
                        path == '/admin' || path.startsWith('/admin/');
                    final headerLinks = onArtistPortal
                        ? const [('Forsiden', '/'), ('Admin', '/admin')]
                        : onAdmin
                        ? const [('Forsiden', '/'), ('Artist', '/min-side')]
                        : const [('Artist', '/min-side'), ('Admin', '/admin')];
                    final linkStyle = TextButton.styleFrom(
                      foregroundColor: AppColors.onImage,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                    Future<void> goHeader(String path) async {
                      // «Artist» skal være vanlig artistportal, ikke siste
                      // admin «se som artist»-økt.
                      if (path == '/min-side') {
                        final repo = PortalScope.of(context).repository;
                        if (repo.adminViewAsArtist != null) {
                          try {
                            await repo.closeArtistPortalAsAdmin();
                          } catch (_) {}
                        }
                      }
                      if (!context.mounted) return;
                      context.go(path);
                    }

                    final links = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final link in headerLinks)
                          TextButton(
                            style: linkStyle,
                            onPressed: () => goHeader(link.$2),
                            child: Text(link.$1),
                          ),
                      ],
                    );
                    if (narrow) {
                      return Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: logo,
                            ),
                          ),
                          links,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(width: reserved),
                        Expanded(child: Center(child: logo)),
                        SizedBox(
                          width: reserved,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: links,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ),
          ColoredBox(
            color: AppColors.hero.withValues(alpha: 0.72),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: 8,
              ),
              child: Center(
                child: Text(
                  'Booking, management og advance gjort enkelt for deg',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onImageMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 720 ? 20.0 : 32.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 36, horizontal, 72),
          child: child,
        ),
      ),
    );
  }
}

class CenteredStatus extends StatelessWidget {
  const CenteredStatus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(32), child: child),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CenteredStatus(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Prøv igjen')),
        ],
      ),
    );
  }
}

class AdminArtistViewBanner extends StatelessWidget {
  const AdminArtistViewBanner({super.key, required this.session});

  final ArtistSession session;

  Future<void> _backToAdmin(BuildContext context) async {
    final repository = PortalScope.of(context).repository;
    await repository.closeArtistPortalAsAdmin();
    if (!context.mounted) return;
    context.go('/admin/artister');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.ink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  'Du ser nå på portalen som ${session.artistName} (Admin-modus).',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onImage,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onImage,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _backToAdmin(context),
                  child: const Text('Tilbake til adminportal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Siden finnes ikke',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('Gå tilbake til artistene.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Til artister'),
            ),
          ],
        ),
      ),
    );
  }
}
