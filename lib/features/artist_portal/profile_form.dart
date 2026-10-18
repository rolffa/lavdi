import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../models/band.dart';

class MemberProfileForm extends StatefulWidget {
  const MemberProfileForm({
    super.key,
    required this.initial,
    required this.onSave,
    this.includePassword = false,
  });

  final BandMember initial;
  final bool includePassword;
  final Future<void> Function({
    required String name,
    required String role,
    required String phone,
    required String food,
    required String personalTech,
    String? password,
  })
  onSave;

  @override
  State<MemberProfileForm> createState() => _MemberProfileFormState();
}

class _MemberProfileFormState extends State<MemberProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _phone;
  late final TextEditingController _food;
  late final TextEditingController _tech;
  late final TextEditingController _password;
  late final TextEditingController _confirm;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _role = TextEditingController(text: widget.initial.role);
    _phone = TextEditingController(text: widget.initial.phone);
    _food = TextEditingController(text: widget.initial.food);
    _tech = TextEditingController(text: widget.initial.personalTech);
    _password = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _food.dispose();
    _tech.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        name: _name.text,
        role: _role.text,
        phone: _phone.text,
        food: _food.text,
        personalTech: _tech.text,
        password: widget.includePassword ? _password.text : null,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalTextFormField(
            controller: _name,
            label: 'Navn',
            textCapitalization: TextCapitalization.words,
            validator: _required('Oppgi navn'),
          ),
          const SizedBox(height: 12),
          PortalTextFormField(
            controller: _role,
            label: 'Rolle / instrument',
            helperText: 'For eksempel musiker, lydtekniker eller turnéleder',
            textCapitalization: TextCapitalization.sentences,
            validator: _required('Oppgi rolle eller instrument'),
          ),
          const SizedBox(height: 12),
          PortalTextFormField(
            controller: _phone,
            label: 'Telefon',
            keyboardType: TextInputType.phone,
            validator: _required('Oppgi telefonnummer'),
          ),
          const SizedBox(height: 12),
          PortalTextFormField(
            controller: _food,
            label: 'Matpreferanser og allergier',
            helperText: 'Dietter, allergier og spesielle ønsker',
            alignLabelWithHint: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            validator: _required('Oppgi mat, allergier eller skriv Ingen'),
          ),
          const SizedBox(height: 12),
          PortalTextFormField(
            controller: _tech,
            label: 'Personlige tekniske behov',
            helperText: 'IEM, trådløse frekvenser, mikrofon, DI-bokser og strøm',
            alignLabelWithHint: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            validator: _required('Oppgi tekniske behov eller skriv Ingen'),
          ),
          if (widget.includePassword) ...[
            const SizedBox(height: 20),
            Text('Lag innloggingspassord', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Brukes neste gang du logger inn på Min side med e-post.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onImageMuted,
              ),
            ),
            const SizedBox(height: 12),
            PortalTextFormField(
              controller: _password,
              label: 'Passord',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Passordet må være minst 6 tegn';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            PortalTextFormField(
              controller: _confirm,
              label: 'Bekreft passord',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value != _password.text) {
                  return 'Passordene er ikke like';
                }
                return null;
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            FieldError(_error!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving
                    ? 'Lagrer…'
                    : widget.includePassword
                    ? 'Lagre profil og passord'
                    : 'Lagre profil',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?) _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }
}
