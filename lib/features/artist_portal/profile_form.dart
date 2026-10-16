import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../models/band.dart';

class MemberProfileForm extends StatefulWidget {
  const MemberProfileForm({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final BandMember initial;
  final Future<void> Function({
    required String name,
    required String role,
    required String phone,
    required String food,
    required String personalTech,
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
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _food.dispose();
    _tech.dispose();
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
    return InkSurface(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Navn'),
              validator: _required('Oppgi navn'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _role,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Rolle / instrument',
                helperText:
                    'For eksempel musiker, lydtekniker eller turnéleder',
                helperStyle: TextStyle(color: AppColors.muted),
              ),
              validator: _required('Oppgi rolle eller instrument'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
              validator: _required('Oppgi telefonnummer'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _food,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Matpreferanser og allergier',
                helperText: 'Dietter, allergier og spesielle ønsker',
                helperStyle: TextStyle(color: AppColors.muted),
                alignLabelWithHint: true,
              ),
              validator: _required('Oppgi mat, allergier eller skriv Ingen'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tech,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Personlige tekniske behov',
                helperText:
                    'IEM, trådløse frekvenser, mikrofon, DI-bokser og strøm',
                helperStyle: TextStyle(color: AppColors.muted),
                alignLabelWithHint: true,
              ),
              validator: _required('Oppgi tekniske behov eller skriv Ingen'),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Lagrer…' : 'Lagre profil'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? Function(String?) _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }
}
