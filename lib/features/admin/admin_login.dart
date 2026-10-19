import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PortalScope.of(context).repository.signInAdmin(
        username: _username.text,
        password: _password.text,
      );
      if (!mounted) return;
      widget.onSignedIn();
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: InkSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalTextFormField(
                controller: _username,
                label: 'Brukernavn',
                textInputAction: TextInputAction.next,
                autofocus: true,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Skriv brukernavn' : null,
              ),
              const SizedBox(height: 12),
              PortalTextFormField(
                controller: _password,
                label: 'Passord',
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Skriv passord' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FieldError(_error!),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Logger inn…' : 'Logg inn'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
