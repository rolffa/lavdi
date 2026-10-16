import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/booking_deal.dart';
import '../shell/portal_scaffold.dart';
import 'admin_login.dart';

class AdminArchivePage extends StatefulWidget {
  const AdminArchivePage({super.key});

  @override
  State<AdminArchivePage> createState() => _AdminArchivePageState();
}

class _AdminArchivePageState extends State<AdminArchivePage> {
  var _loading = false;
  Object? _error;
  List<BookingDeal> _deals = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PortalScope.of(context).repository.isAdminSignedIn) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deals =
          await PortalScope.of(context).repository.fetchArchivedDeals();
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = PortalScope.of(context).repository.isAdminSignedIn;
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => context.go('/admin'),
                  child: const Text(
                    'Tilbake til forespørsler',
                    style: TextStyle(color: AppColors.onImage),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Arkiv',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.onImage,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Avslåtte forespørsler du har arkivert.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onImage,
                  ),
                ),
                const SizedBox(height: 20),
                if (!signedIn)
                  AdminLogin(onSignedIn: _load)
                else if (_loading)
                  const CenteredStatus(child: CircularProgressIndicator())
                else if (_error != null)
                  ErrorRetry(
                    message: readableError(_error!),
                    onRetry: _load,
                  )
                else if (_deals.isEmpty)
                  Text(
                    'Arkivet er tomt.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onImage,
                    ),
                  )
                else
                  for (final deal in _deals) ...[
                    _ArchivedDealCard(deal: deal, onChanged: _load),
                    const SizedBox(height: 16),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedDealCard extends StatefulWidget {
  const _ArchivedDealCard({required this.deal, required this.onChanged});

  final BookingDeal deal;
  final Future<void> Function() onChanged;

  @override
  State<_ArchivedDealCard> createState() => _ArchivedDealCardState();
}

class _ArchivedDealCardState extends State<_ArchivedDealCard> {
  var _busy = false;
  String? _error;

  Future<void> _unarchive() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PortalScope.of(context).repository.unarchiveDeal(widget.deal.id);
      if (!mounted) return;
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: InkSurface(
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arkivert',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(deal.artistName, style: theme.textTheme.titleLarge),
                  Text(formatLongDate(deal.date)),
                  Text(deal.venue),
                  Text(deal.organizerName),
                  if (deal.email.isNotEmpty) Text(deal.email),
                  if (deal.fee != null) Text(formatNok(deal.fee!)),
                  if (deal.declineComment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Avslag: ${deal.declineComment}'),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _unarchive,
                    child: Text(_busy ? 'Lagrer…' : 'Ta bort fra arkiv'),
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
