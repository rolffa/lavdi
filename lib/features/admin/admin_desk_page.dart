import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/artist_slug.dart';
import '../../core/config.dart';
import '../../core/deal_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../core/travel_pdf.dart';
import '../../models/booking_deal.dart';
import '../../models/member_conflict.dart';
import '../../web/rider_files.dart';
import '../shared/member_conflict_notice.dart';
import '../shell/portal_scaffold.dart';
import 'admin_login.dart';

class AdminDeskPage extends StatefulWidget {
  const AdminDeskPage({super.key});

  @override
  State<AdminDeskPage> createState() => _AdminDeskPageState();
}

class _AdminDeskPageState extends State<AdminDeskPage> {
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
      final deals = await PortalScope.of(context).repository.fetchDeals();
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin',
                  style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                ),
                const SizedBox(height: 8),
                Text(
                  'Forespørsler fra arrangører lander her. Artisten ser dem først når du sender dem videre.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
                ),
                const SizedBox(height: 12),
                if (PortalScope.of(context).repository.isAdminSignedIn)
                  TextButton(
                    onPressed: () {
                      PortalScope.of(context).repository.signOutAdmin();
                      setState(() => _deals = const []);
                    },
                    child: const Text(
                      'Logg ut',
                      style: TextStyle(color: AppColors.onImage),
                    ),
                  ),
                const SizedBox(height: 20),
                if (!PortalScope.of(context).repository.isAdminSignedIn)
                  AdminLogin(onSignedIn: () => _load())
                else if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(
                    readableError(_error!),
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
                  )
                else if (_deals.isEmpty)
                  Text(
                    'Ingen forespørsler ennå.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.onImage),
                  )
                else
                  for (final deal in _deals) ...[
                    _DealCard(
                      deal: deal,
                      onChanged: _load,
                    ),
                    const SizedBox(height: 16),
                  ],
                if (PortalScope.of(context).repository.isAdminSignedIn) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/admin/arkiv'),
                    child: const Text(
                      'Arkiv',
                      style: TextStyle(color: AppColors.onImage),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatefulWidget {
  const _DealCard({required this.deal, required this.onChanged});

  final BookingDeal deal;
  final Future<void> Function() onChanged;

  @override
  State<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<_DealCard> {
  late final TextEditingController _fee;
  late final TextEditingController _message;
  var _busy = false;
  String? _error;
  List<MemberDateConflict> _conflicts = const [];

  @override
  void initState() {
    super.initState();
    _fee = TextEditingController(text: widget.deal.fee?.toString() ?? '');
    _message = TextEditingController(text: widget.deal.message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConflicts();
    });
  }

  @override
  void didUpdateWidget(covariant _DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id || oldWidget.deal.status != widget.deal.status) {
      _fee.text = widget.deal.fee?.toString() ?? '';
      _message.text = widget.deal.message;
      _loadConflicts();
    }
  }

  Future<void> _loadConflicts() async {
    try {
      final conflicts = await PortalScope.of(context).repository
          .fetchMemberConflicts(
            artistId: widget.deal.artistId,
            date: widget.deal.date,
          );
      if (!mounted) return;
      setState(() => _conflicts = conflicts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _conflicts = const []);
    }
  }

  @override
  void dispose() {
    _fee.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final fee = int.tryParse(_fee.text.trim());
    if (fee == null || fee < 0) {
      setState(() => _error = 'Skriv honorar i kroner');
      return;
    }
    await _run(
      () => PortalScope.of(context).repository.sendDealToArtist(
        dealId: widget.deal.id,
        fee: fee,
        message: _message.text,
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final deal = widget.deal;
    final bytes = await buildCrewTravelPdf(
      artistName: deal.artistName,
      date: deal.date,
      venue: deal.venue,
      organizerName: deal.organizerName,
      crew: deal.crew,
    );
    if (!mounted) return;
    saveBytes(Uint8List.fromList(bytes), 'reise-${deal.artistName}.pdf', 'application/pdf');
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final now = DateTime.now();
    final expired = deal.withArtist && !deal.replyOpen(now);
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
            Text(_statusLabel(deal, expired), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(deal.artistName, style: theme.textTheme.titleLarge),
            Text(formatLongDate(deal.date)),
            Text(deal.venue),
            Text(deal.organizerName),
            if (deal.email.isNotEmpty) Text(deal.email),
            if (deal.fee != null) Text(formatNok(deal.fee!)),
            if (deal.withArtist && deal.deadline != null) ...[
              const SizedBox(height: 6),
              Text(replyWindowLabel(deal.deadline!, now)),
            ],
            if (deal.declined && deal.declineComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Avslag: ${deal.declineComment}'),
            ],
            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 12),
              MemberConflictNotice(
                conflicts: _conflicts,
                title: 'Obs: medlem opptatt i annet band',
                compact: true,
              ),
            ],
            const SizedBox(height: 12),
            _actions(deal, expired),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!),
            ],
          ],
        ),
      );
        },
      ),
      ),
    );
  }

  Widget _actions(BookingDeal deal, bool expired) {
    if (deal.inquiry || deal.declined || expired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _fee,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: portalFieldStyle,
            cursorColor: AppColors.ink,
            decoration: fieldDecoration(label: 'Honorar'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            minLines: 2,
            maxLines: 4,
            style: portalFieldStyle,
            cursorColor: AppColors.ink,
            decoration: fieldDecoration(label: 'Melding til artisten'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(_busy ? 'Sender…' : 'Send til artist'),
              ),
              if (deal.declined) ...[
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => PortalScope.of(context)
                              .repository
                              .archiveDeal(deal.id),
                        ),
                  child: Text(_busy ? 'Lagrer…' : 'Arkiver'),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => PortalScope.of(context)
                              .repository
                              .confirmDeal(deal.id),
                        ),
                  child: Text(_busy ? 'Lagrer…' : 'Bekreft likevel'),
                ),
              ],
            ],
          ),
        ],
      );
    }
    if (deal.accepted || deal.adminSigned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Huk av når du og arrangøren har signert.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => PortalScope.of(context).repository.confirmDeal(deal.id),
                  ),
            child: Text(_busy ? 'Lagrer…' : 'Bekreftet'),
          ),
        ],
      );
    }
    if (deal.confirmed) {
      final slug = artistSlug(deal.artistName);
      final origin = AppConfig.environment.publicSiteUrl;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.pressReady
                ? 'Pressepakke er klar til ${deal.email.isEmpty ? 'arrangøren' : deal.email}.'
                : 'Pressepakke er ikke klar.',
          ),
          Text('$origin/artister/$slug/presse'),
          const SizedBox(height: 8),
          const Text('Først: arrangør fyller reiseinfo (flyplass, avstand, mer info)'),
          SelectableText('$origin/arrangor/reise/${deal.travelToken}'),
          const SizedBox(height: 8),
          Text('Dagskjema. Frist ${formatLongDate(daySheetDue(deal.date))}.'),
          SelectableText('$origin/arrangor/dag/${deal.dayToken}'),
          if (deal.travelBriefReady) ...[
            const SizedBox(height: 8),
            Text('Flyplass: ${deal.airport}'),
            Text('Avstand: ${deal.airportDistance}'),
            if (deal.route.isNotEmpty) Text('Mer info: ${deal.route}'),
            const Text('Artisten er varslet om å bestille reise.'),
          ] else ...[
            const SizedBox(height: 8),
            const Text('Venter på arrangørens reiseinfo før artisten bestiller.'),
          ],
          if (deal.daySheetReady) ...[
            const SizedBox(height: 8),
            const Text('Dagskjemaet er levert. Artisten ser det i konserten.'),
          ],
          if (crewTravelComplete(deal.crew)) ...[
            const SizedBox(height: 12),
            Text(
              'Alle som skal være med har bestilt reise. PDF-en kan sendes til ${deal.email.isEmpty ? 'arrangøren' : deal.email}.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _downloadPdf,
              child: const Text('Last ned reisepdf'),
            ),
          ] else if (deal.travelBriefReady) ...[
            const SizedBox(height: 8),
            const Text('Venter på at alle aktive medlemmer huker av for reise bestilt.'),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _statusLabel(BookingDeal deal, bool expired) {
    if (expired) return 'Svarfrist ute';
    return switch (deal.status) {
      DealStatus.inquiry => 'Ny forespørsel',
      DealStatus.withArtist => 'Hos artist',
      DealStatus.declined => 'Artist sa nei',
      DealStatus.accepted => 'Artist sa ja',
      DealStatus.adminSigned => 'Artist sa ja',
      DealStatus.confirmed => 'Bekreftet',
      _ => deal.status,
    };
  }
}
