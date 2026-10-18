import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../web/press_files.dart';

class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Section titles must never inherit on-image (light) text colors from the
    // portal chrome — those are near-invisible on AppColors.surface cards.
    const titleStyle = TextStyle(
      color: AppColors.ink,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.2,
    );
    const bodyStyle = TextStyle(
      color: AppColors.ink,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
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
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: bodyStyle),
                ],
                const SizedBox(height: 16),
                DefaultTextStyle.merge(
                  style: bodyStyle,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordChangeForm extends StatefulWidget {
  const PasswordChangeForm({super.key, required this.onSubmit});

  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  }) onSubmit;

  @override
  State<PasswordChangeForm> createState() => _PasswordChangeFormState();
}

class _PasswordChangeFormState extends State<PasswordChangeForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.trim() != _confirm.text.trim()) {
      setState(() {
        _error = 'Passordene er ikke like';
        _message = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.onSubmit(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() {
        _busy = false;
        _message = 'Passordet er oppdatert.';
      });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          style: portalFieldStyle,
          cursorColor: AppColors.ink,
          decoration: fieldDecoration(label: 'Nåværende passord'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _next,
          obscureText: true,
          style: portalFieldStyle,
          cursorColor: AppColors.ink,
          decoration: fieldDecoration(label: 'Nytt passord'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          style: portalFieldStyle,
          cursorColor: AppColors.ink,
          decoration: fieldDecoration(label: 'Bekreft nytt passord'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          FieldError(_error!),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Lagrer…' : 'Endre passord'),
        ),
      ],
    );
  }
}

class AvatarUploadRow extends StatelessWidget {
  const AvatarUploadRow({
    super.key,
    required this.imageUrl,
    required this.busy,
    required this.onPick,
    this.label = 'Profilbilde',
  });

  final String? imageUrl;
  final bool busy;
  final Future<void> Function() onPick;
  final String label;

  bool get _network =>
      imageUrl != null &&
      (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.paper,
          backgroundImage: _network ? NetworkImage(imageUrl!) : null,
          child: _network
              ? null
              : Text(
                  imageUrl == null ? '?' : 'OK',
                  style: const TextStyle(color: AppColors.ink),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.ink, fontSize: 15),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy ? null : onPick,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink),
                ),
                child: Text(busy ? 'Laster…' : 'Last opp bilde'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<({String name, List<int> bytes})?> pickAccountPhoto() async {
  final picked = await pickPressPhoto();
  if (picked == null) return null;
  return (name: picked.name, bytes: picked.bytes);
}
