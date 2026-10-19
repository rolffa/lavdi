import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/artist.dart';
import '../../models/artist_offer.dart';
import '../../models/member_conflict.dart';
import '../shared/member_conflict_notice.dart';
import '../shell/portal_scaffold.dart';
import 'admin_login.dart';

class AdminOfferPage extends StatefulWidget {
  const AdminOfferPage({super.key});

  @override
  State<AdminOfferPage> createState() => _AdminOfferPageState();
}

class _AdminOfferPageState extends State<AdminOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _organizerController = TextEditingController();
  final _feeController = TextEditingController();
  final _messageController = TextEditingController();

  var _loadingArtists = false;
  Object? _loadError;
  List<Artist> _artists = const [];
  List<ArtistOffer> _declined = const [];
  String? _artistId;
  DateTime? _date;
  List<MemberDateConflict> _conflicts = const [];
  var _loadingConflicts = false;
  var _sending = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (PortalScope.of(context).repository.isAdminSignedIn) _loadArtists();
    });
  }

  @override
  void dispose() {
    _venueController.dispose();
    _organizerController.dispose();
    _feeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadArtists() async {
    setState(() {
      _loadingArtists = true;
      _loadError = null;
    });
    final repository = PortalScope.of(context).repository;
    try {
      final artists = await repository.fetchAdminArtists();
      final declined = await repository.fetchDeclinedOffers();
      if (!mounted) return;
      setState(() {
        _artists = artists;
        _declined = declined;
        _artistId = artists.isEmpty ? null : artists.first.id;
        _loadingArtists = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingArtists = false;
        _loadError = error;
      });
    }
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = dateOnly(picked));
    await _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    final artistId = _artistId;
    final date = _date;
    if (artistId == null || date == null) {
      setState(() => _conflicts = const []);
      return;
    }
    setState(() => _loadingConflicts = true);
    try {
      final conflicts = await PortalScope.of(context).repository
          .fetchMemberConflicts(artistId: artistId, date: date);
      if (!mounted) return;
      setState(() {
        _conflicts = conflicts;
        _loadingConflicts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conflicts = const [];
        _loadingConflicts = false;
      });
    }
  }

  Future<void> _send() async {
    final artistId = _artistId;
    if (_sending || artistId == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final fee = int.tryParse(
      _feeController.text.trim().replaceAll(RegExp(r'\s'), ''),
    );
    if (fee == null || _date == null) return;
    setState(() {
      _sending = true;
      _error = null;
      _message = null;
    });
    try {
      await PortalScope.of(context).repository.sendOffer(
        artistId: artistId,
        date: _date!,
        fee: fee,
        venue: _venueController.text,
        organizerName: _organizerController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      final artist = _artists.where((item) => item.id == artistId).firstOrNull;
      setState(() {
        _sending = false;
        _message = 'Tilbudet er sendt til ${artist?.name ?? 'artisten'}.';
        _venueController.clear();
        _organizerController.clear();
        _feeController.clear();
        _messageController.clear();
        _date = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = PortalScope.of(context).repository.isAdminSignedIn;
    return PortalScaffold(
      body: ListView(
        children: [
          PageFrame(
            maxWidth: 760,
            child: !signedIn
                ? AdminLogin(onSignedIn: _loadArtists)
                : _loadingArtists
                ? const CenteredStatus(child: CircularProgressIndicator())
                : _loadError != null
                ? ErrorRetry(
                    message: readableError(_loadError!),
                    onRetry: _loadArtists,
                  )
                : _form(context),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    if (_artists.isEmpty) return const Text('Ingen artister er lagt inn ennå.');
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TILBUD',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.onImageMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text('Send tilbud', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
          const SizedBox(height: 10),
          Text(
            'Tilbudet vises under Forespørsler i artistportalen. Honorar vises bare der, ikke på den offentlige artistsiden.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.onImageMuted,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
            ),
            child: InkSurface(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _artistId,
                      style: portalFieldStyle,
                      decoration: fieldDecoration(label: 'Artist'),
                      items: [
                        for (final artist in _artists)
                          DropdownMenuItem(
                            value: artist.id,
                            child: Text(artist.name),
                          ),
                      ],
                      onChanged: _sending
                          ? null
                          : (value) {
                              setState(() => _artistId = value);
                              _loadConflicts();
                            },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _sending ? null : _pickDate,
                      child: Text(
                        _date == null ? 'Velg dato' : formatLongDate(_date!),
                      ),
                    ),
                    if (_loadingConflicts) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_conflicts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      MemberConflictNotice(
                        conflicts: _conflicts,
                        title: 'Obs: medlem opptatt i annet band',
                      ),
                    ],
                    const SizedBox(height: 12),
                    PortalTextFormField(
                      controller: _venueController,
                      label: 'Spillested',
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Skriv spillested'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    PortalTextFormField(
                      controller: _organizerController,
                      label: 'Arrangør',
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Skriv arrangør'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    PortalTextFormField(
                      controller: _feeController,
                      label: 'Honorar i kroner',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final fee = int.tryParse((value ?? '').trim());
                        if (fee == null) return 'Skriv honorar';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    PortalTextFormField(
                      controller: _messageController,
                      label: 'Melding til artisten',
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      FieldError(_error!),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(color: AppColors.available),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _sending || _date == null ? null : _send,
                      child: Text(_sending ? 'Sender…' : 'Send tilbud'),
                    ),
                    if (_date == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Velg dato før du sender.',
                        style: const TextStyle(color: AppColors.ink),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'AVSLÅTTE TILBUD',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.onImageMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (_declined.isEmpty)
            Text(
              'Ingen avslåtte tilbud.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onImageMuted,
              ),
            )
          else
            for (final offer in _declined) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  color: AppColors.paper,
                ),
                child: InkSurface(
                  child: Builder(
                    builder: (context) {
                      final card = Theme.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${offer.artistName} · ${offer.venue}',
                            style: card.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(formatLongDate(offer.date)),
                          const SizedBox(height: 8),
                          Text(offer.declineComment),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
