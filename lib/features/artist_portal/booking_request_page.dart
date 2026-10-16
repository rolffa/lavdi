import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../models/booking_request.dart';
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
      final request = await PortalScope.of(context).repository
          .fetchBookingRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = request;
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
