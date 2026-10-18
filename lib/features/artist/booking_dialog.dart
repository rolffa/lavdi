import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/artist.dart';
import '../../models/booking_draft.dart';
import '../../web/dialog_overlay.dart';

class BookingDialog extends StatefulWidget {
  const BookingDialog({super.key, required this.artist, required this.date});

  final Artist artist;
  final DateTime date;

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _organizer = TextEditingController();
  final _organization = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _venue = TextEditingController();
  final _notes = TextEditingController();

  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    holdDialogOverlay();
  }

  @override
  void dispose() {
    releaseDialogOverlay();
    _organizer.dispose();
    _organization.dispose();
    _contact.dispose();
    _email.dispose();
    _phone.dispose();
    _venue.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _dismiss([bool sent = false]) {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop(sent);
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final repository = PortalScope.of(context).repository;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await repository.submitBooking(
        BookingDraft(
          artistId: widget.artist.id,
          date: widget.date,
          organizerName: _organizer.text,
          organization: _organization.text,
          contactPerson: _contact.text,
          email: _email.text,
          phone: _phone.text,
          venueCity: _venue.text,
          notes: _notes.text,
        ),
      );
      if (!mounted) return;
      _dismiss(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width < 600 ? width - 32 : 560.0;

    return InkSurface(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: _form(theme, dialogWidth),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form(ThemeData theme, double dialogWidth) {
    final sideBySide = dialogWidth >= 520;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bookingforespørsel', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(widget.artist.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(formatLongDate(widget.date), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          TextFormField(
            controller: _organizer,
            style: portalFieldStyle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(label: 'Arrangørnavn'),
            validator: (value) => requiredField(value, 'Oppgi arrangørnavn'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _organization,
            style: portalFieldStyle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(label: 'Organisasjon / firma'),
            validator: (value) => requiredField(value, 'Oppgi organisasjon'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contact,
            style: portalFieldStyle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(label: 'Kontaktperson'),
            validator: (value) => requiredField(value, 'Oppgi kontaktperson'),
          ),
          const SizedBox(height: 12),
          _pair(
            sideBySide: sideBySide,
            first: TextFormField(
              controller: _email,
              style: portalFieldStyle,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: fieldDecoration(label: 'E-post'),
              validator: emailField,
            ),
            second: TextFormField(
              controller: _phone,
              style: portalFieldStyle,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: fieldDecoration(label: 'Telefon'),
              validator: phoneField,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _venue,
            style: portalFieldStyle,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(label: 'Spillested / by'),
            validator: (value) =>
                requiredField(value, 'Oppgi spillested og by'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            style: portalFieldStyle,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            decoration: fieldDecoration(label: 'Notater'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.busy,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(
                onPressed: _submitting ? null : () => _dismiss(),
                child: const Text('Avbryt'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Sender…' : 'Send forespørsel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pair({
    required bool sideBySide,
    required Widget first,
    required Widget second,
  }) {
    if (!sideBySide) {
      return Column(children: [first, const SizedBox(height: 12), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}
