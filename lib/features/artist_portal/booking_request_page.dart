import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/booking_request.dart';
import '../../models/member_conflict.dart';
import '../shared/member_conflict_notice.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class BookingRequestPage extends StatefulWidget {
  const BookingRequestPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<BookingRequestPage> createState() => _BookingRequestPageState();
}

class _BookingRequestPageState extends State<BookingRequestPage> {
  BookingRequest? _request;
  List<MemberDateConflict> _conflicts = const [];
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = PortalScope.of(context).repository;
      final request = await repository.fetchBookingRequest(widget.requestId);
      var conflicts = const <MemberDateConflict>[];
      if (request != null) {
        final session = await repository.currentArtist();
        if (session != null) {
          conflicts = await repository.fetchMemberConflicts(
            artistId: session.artistId,
            date: request.date,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _request = request;
        _conflicts = conflicts;
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
    final request = _request;
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                ArtistFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ArtistBackButton(
                        label: 'Konserter',
                        path: '/min-side',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bookingforespørsel',
                        style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      else if (request == null)
                        Text(
                          'Fant ikke forespørselen. Logg inn som bandleder eller admin for bandet.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.onImage,
                          ),
                        )
                      else ...[
                        Text(
                          request.artistName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.onImage,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatLongDate(request.date),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.onImage,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Line(label: 'Arrangør', value: request.organizerName),
                        _Line(
                          label: 'Organisasjon',
                          value: request.organization,
                        ),
                        _Line(label: 'Sted', value: request.venue),
                        _Line(label: 'Kontakt', value: request.contactPerson),
                        _Line(label: 'E-post', value: request.email),
                        _Line(label: 'Telefon', value: request.phone),
                        if (request.notes.isNotEmpty)
                          _Line(label: 'Notater', value: request.notes),
                        if (_conflicts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          MemberConflictNotice(
                            conflicts: _conflicts,
                            onImage: true,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.onImageMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
