import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/deal_logic.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/setlist_logic.dart';
import '../../core/theme.dart';
import '../../data/demo_catalog.dart';
import '../../models/artist_offer.dart';
import '../../models/artist_session.dart';
import '../../models/band.dart';
import '../../models/gig.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';
import 'profile_form.dart';
import 'push_card.dart';

class MinSidePage extends StatefulWidget {
  const MinSidePage({super.key});

  @override
  State<MinSidePage> createState() => _MinSidePageState();
}

class _MinSidePageState extends State<MinSidePage> {
  ArtistSession? _session;
  BandOverview? _band;
  List<Gig> _gigs = const [];
  List<ArtistOffer> _offers = const [];
  String? _reportGigId;
  String? _offerBusy;
  String? _offerError;
  Object? _error;
  var _loading = true;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router;
      router.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    if (!mounted || _loading) return;
    if (_router?.state.uri.path == '/min-side') _load();
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await repository.currentArtist();
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _session = null;
          _band = null;
          _loading = false;
        });
        return;
      }
      final band = await repository.fetchMyBand();
      final gigs = await repository.fetchMyGigs();
      final offers = await repository.fetchMyOffers();
      String? reportId;
      final today = dateOnly(DateTime.now());
      for (final gig in gigs) {
        final setlist = await repository.fetchSetlist(gig.id);
        if (gigNeedsSetlistReport(
          gigDate: gig.date,
          today: today,
          confirmed: setlist.confirmed,
        )) {
          reportId = gig.id;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _band = band;
        _gigs = gigs;
        _offers = offers;
        _reportGigId = reportId;
        _offerBusy = null;
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

  Future<void> _respond(String offerId, bool approve, String comment) async {
    setState(() {
      _offerBusy = offerId;
      _offerError = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      await repository.respondToOffer(
        offerId: offerId,
        approve: approve,
        comment: comment,
      );
      final gigs = await repository.fetchMyGigs();
      final offers = await repository.fetchMyOffers();
      if (!mounted) return;
      setState(() {
        _gigs = gigs;
        _offers = offers;
        _offerBusy = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _offerBusy = null;
        _offerError = readableError(error);
      });
    }
  }

  Future<void> _undoDecline(String offerId) async {
    setState(() {
      _offerBusy = offerId;
      _offerError = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      await repository.undoOfferDecline(offerId);
      final offers = await repository.fetchMyOffers();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _offerBusy = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _offerBusy = null;
        _offerError = readableError(error);
      });
    }
  }

  Future<void> _signOut() async {
    final wasAdminView = _session?.asAdmin ?? false;
    await PortalScope.of(context).repository.signOutArtist();
    if (!mounted) return;
    if (wasAdminView) {
      context.go('/admin/artister');
      return;
    }
    setState(() {
      _session = null;
      _band = null;
      _gigs = const [];
      _offers = const [];
      _reportGigId = null;
      _offerBusy = null;
      _offerError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PortalScaffold(
      artistMenu: _session != null,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : _error != null && _session == null
          ? ErrorRetry(message: readableError(_error!), onRetry: _load)
          : ListView(
              children: [
                if (_session == null)
                  _LoginPanel(onSignedIn: _load)
                else if (_band != null &&
                    !_band!.me.profileComplete &&
                    !_session!.asAdmin)
                  _ProfileGate(
                    member: _band!.me,
                    onSaved: _load,
                    onSignOut: _signOut,
                  )
                else
                  _Home(
                    session: _session!,
                    gigs: _gigs,
                    offers: _offers,
                    reportGigId: _reportGigId,
                    offerBusyId: _offerBusy,
                    offerError: _offerError,
                    onRespond: _respond,
                    onUndoDecline: _undoDecline,
                    onSignOut: _signOut,
                    member: _band?.me,
                  ),
              ],
            ),
    );
  }
}

class _LoginPanel extends StatefulWidget {
  const _LoginPanel({required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _message;
  var _messageIsError = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() != true) return;
    await _run(() async {
      await PortalScope.of(context).repository
          .signInArtist(email: _email.text, password: _password.text);
      await widget.onSignedIn();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = readableError(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = PortalScope.of(context).demoMode;
    return ArtistFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ARTIST', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              'Min side',
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.onImage,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kjøreplan, reise og settliste for dine konserter.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.onImageMuted,
              ),
            ),
            const SizedBox(height: 24),
            PortalTextFormField(
              controller: _email,
              label: 'E-post',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Oppgi e-post';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            PortalTextFormField(
              controller: _password,
              label: 'Passord',
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _signIn(),
              validator: (value) =>
                  value == null || value.length < 4 ? 'Oppgi passord' : null,
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _messageIsError ? AppColors.busy : AppColors.onImage,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Text(_busy ? 'Logger inn…' : 'Logg inn'),
              ),
            ),
            if (demo) ...[
              const SizedBox(height: 20),
              Text(
                'Demobruker: ${DemoCatalog.artistEmail} / ${DemoCatalog.artistPassword}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onImageMuted,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          _email.text = DemoCatalog.artistEmail;
                          _password.text = DemoCatalog.artistPassword;
                          await _signIn();
                        },
                  child: const Text('Logg inn som Rolffa'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({
    required this.session,
    required this.gigs,
    required this.offers,
    required this.reportGigId,
    required this.offerBusyId,
    required this.offerError,
    required this.onRespond,
    required this.onUndoDecline,
    required this.onSignOut,
    required this.member,
  });

  final ArtistSession session;
  final List<Gig> gigs;
  final List<ArtistOffer> offers;
  final String? reportGigId;
  final String? offerBusyId;
  final String? offerError;
  final void Function(String offerId, bool approve, String comment) onRespond;
  final void Function(String offerId) onUndoDecline;
  final VoidCallback onSignOut;
  final BandMember? member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final upcoming = gigs
        .where((gig) => !dateOnly(gig.date).isBefore(today))
        .toList();
    final past = gigs
        .where((gig) => dateOnly(gig.date).isBefore(today))
        .toList()
        .reversed
        .toList();
    final report = reportGigId == null
        ? null
        : gigs.where((gig) => gig.id == reportGigId).firstOrNull;

    return ArtistFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.artistName,
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.onImage,
            ),
          ),
          Text(
            session.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onImageMuted,
            ),
          ),
          if (member != null &&
              showPushCard(isLeader: member!.isLeader, role: member!.role)) ...[
            const SizedBox(height: 16),
            LeaderMailCard(email: session.email),
          ],
          const SizedBox(height: 16),
          if (report != null) ...[
            Material(
              color: const Color(0xFFFFF6F4),
              child: InkWell(
                onTap: () => context.go('/min-side/gig/${report.id}/settliste'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.busy, width: 1.5),
                  ),
                  child: InkSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Husk å bekrefte settliste for gårsdagens konsert',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.busy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_gigTitle(report)),
                        const SizedBox(height: 12),
                        Text(
                          'Bekreft settliste',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.busy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
          _SectionBox(
            title: 'Forespørsler',
            caption: 'Tilbud som venter på svar',
            tone: _SectionTone.request,
            children: [
              if (offerError != null)
                Text(
                  offerError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.busy,
                  ),
                ),
              if (offers.isEmpty)
                Text(
                  'Ingen forespørsler.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                )
              else
                for (final offer in offers)
                  _OfferCard(
                    offer: offer,
                    busy: offerBusyId == offer.id,
                    onRespond: offerBusyId == null ? onRespond : null,
                    onUndoDecline: offerBusyId == null ? onUndoDecline : null,
                  ),
            ],
          ),
          const SizedBox(height: 20),
          _GigGroup(
            title: 'Kommende',
            caption: 'Bekreftede konserter',
            gigs: upcoming,
            empty: 'Ingen kommende konserter.',
            past: false,
          ),
          const SizedBox(height: 20),
          _GigGroup(
            title: 'Tidligere',
            caption: 'Avsluttede konserter',
            gigs: past,
            empty: 'Ingen tidligere konserter.',
            past: true,
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: onSignOut, child: const Text('Logg ut')),
        ],
      ),
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate({
    required this.member,
    required this.onSaved,
    required this.onSignOut,
  });

  final BandMember member;
  final Future<void> Function() onSaved;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ArtistFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profilen må fylles ut',
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.onImage,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Navn, rolle, telefon, mat og tekniske behov lagres før du ser kjøreplanen.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.onImageMuted,
            ),
          ),
          const SizedBox(height: 20),
          MemberProfileForm(
            initial: member,
            onSave:
                ({
                  required String name,
                  required String role,
                  required String phone,
                  required String food,
                  required String personalTech,
                  String? password,
                }) async {
                  await PortalScope.of(context).repository.saveMyProfile(
                    name: name,
                    role: role,
                    phone: phone,
                    food: food,
                    personalTech: personalTech,
                  );
                  await onSaved();
                },
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onSignOut, child: const Text('Logg ut')),
        ],
      ),
    );
  }
}

enum _SectionTone { request, upcoming, past }

class _SectionBox extends StatelessWidget {
  const _SectionBox({
    required this.title,
    required this.caption,
    required this.tone,
    required this.children,
  });

  final String title;
  final String caption;
  final _SectionTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color borderColor;
    final Color headerColor;
    final Color headerText;
    final Color captionColor;
    final Color bodyColor;
    switch (tone) {
      case _SectionTone.request:
        borderColor = const Color(0xFFC9A227);
        headerColor = const Color(0xFFF0C400);
        headerText = AppColors.ink;
        captionColor = const Color(0xFF6B5410);
        bodyColor = const Color(0xFFFFF8E6);
      case _SectionTone.upcoming:
        borderColor = AppColors.available;
        headerColor = AppColors.available;
        headerText = AppColors.surface;
        captionColor = const Color(0xFFD7E8DC);
        bodyColor = const Color(0xFFF4F8F5);
      case _SectionTone.past:
        borderColor = AppColors.line;
        headerColor = AppColors.paperDeep;
        headerText = AppColors.muted;
        captionColor = AppColors.muted;
        bodyColor = const Color(0xFFEDE8DE);
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bodyColor,
        border: Border.all(
          color: borderColor,
          width: tone == _SectionTone.past ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: headerColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: headerText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: captionColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onRespond,
    required this.onUndoDecline,
  });

  final ArtistOffer offer;
  final bool busy;
  final void Function(String offerId, bool approve, String comment)? onRespond;
  final void Function(String offerId)? onUndoDecline;

  Future<void> _decline(BuildContext context) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => const _DeclineDialog(),
    );
    if (comment == null) return;
    onRespond?.call(offer.id, false, comment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(
            color: offer.declined ? AppColors.muted : const Color(0xFFC9A227),
            width: 4,
          ),
          top: const BorderSide(color: AppColors.line),
          right: const BorderSide(color: AppColors.line),
          bottom: const BorderSide(color: AppColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offer.declined) ...[
            Text(
              'Avslått',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.busy,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(offer.venue, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(formatLongDate(offer.date)),
          Text(offer.organizerName),
          const SizedBox(height: 8),
          Text(formatNok(offer.fee), style: theme.textTheme.titleMedium),
          if (offer.deadline != null) ...[
            const SizedBox(height: 8),
            Text(replyWindowLabel(offer.deadline!, DateTime.now())),
          ],
          if (offer.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              offer.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
          if (offer.declined) ...[
            const SizedBox(height: 12),
            Text('Kommentar', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(offer.declineComment),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: busy || onUndoDecline == null
                  ? null
                  : () => onUndoDecline!(offer.id),
              child: Text(busy ? 'Lagrer…' : 'Angre avslag'),
            ),
          ] else if (offer.deadline != null &&
              !offer.replyOpen(DateTime.now())) ...[
            const SizedBox(height: 14),
            const Text(
              'Svarfristen på 48 timer er ute. Bookingansvarlig må sende forespørselen på nytt.',
            ),
          ] else ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy || onRespond == null
                      ? null
                      : () => onRespond!(offer.id, true, ''),
                  child: Text(busy ? 'Lagrer…' : 'Godkjenn'),
                ),
                OutlinedButton(
                  onPressed: busy || onRespond == null
                      ? null
                      : () => _decline(context),
                  child: const Text('Avslå'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog();

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _comment = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      setState(() => _error = 'Skriv hvorfor forespørselen avslås.');
      return;
    }
    Navigator.of(context).pop(comment);
  }

  @override
  Widget build(BuildContext context) {
    return InkSurface(
      child: AlertDialog(
        title: const Text('Avslå forespørsel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skriv hvorfor forespørselen avslås. Kommentaren sendes til bookingansvarlig.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              style: portalFieldStyle,
              cursorColor: AppColors.ink,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(label: 'Kommentar'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              FieldError(_error!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Avslå')),
        ],
      ),
    );
  }
}

class _GigGroup extends StatelessWidget {
  const _GigGroup({
    required this.title,
    required this.caption,
    required this.gigs,
    required this.empty,
    required this.past,
  });

  final String title;
  final String caption;
  final List<Gig> gigs;
  final String empty;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionBox(
      title: title,
      caption: caption,
      tone: past ? _SectionTone.past : _SectionTone.upcoming,
      children: [
        if (gigs.isEmpty)
          Text(
            empty,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          )
        else
          for (final gig in gigs) _GigCard(gig: gig, past: past),
      ],
    );
  }
}

class _GigCard extends StatelessWidget {
  const _GigCard({required this.gig, required this.past});

  final Gig gig;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = past
        ? theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)
        : theme.textTheme.titleLarge;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: past ? AppColors.muted : AppColors.ink,
    );
    final title = _gigTitle(gig);
    final venue = gig.organizer.venueCity.trim();
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => context.go('/min-side/gig/${gig.id}'),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: past ? 12 : 16,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: past ? AppColors.line : AppColors.ink),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(height: 4),
              Text(formatLongDate(gig.date), style: detailStyle),
              if (venue.isNotEmpty && venue != title)
                Text(venue, style: detailStyle),
            ],
          ),
        ),
      ),
    );
  }
}

String _gigTitle(Gig gig) {
  if (gig.production.eventName.trim().isNotEmpty) {
    return gig.production.eventName.trim();
  }
  if (gig.organizer.venueCity.trim().isNotEmpty) {
    return gig.organizer.venueCity.trim();
  }
  return 'Konsert';
}
