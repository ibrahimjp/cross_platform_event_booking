import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController(text: AdminApi.instance.baseUrl);
  bool _busy = false;
  bool _showServer = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminApi.instance.setBaseUrl(_server.text);
      if (!mounted) return;
      await SessionScope.of(context).signIn(_email.text, _password.text);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = SessionScope.of(context).notice;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1063), brand, Color(0xFF8455EF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EventBook Admin',
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text('Control centre', style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          if (notice != null || _error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Tone.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(_error ?? notice!, style: const TextStyle(color: Tone.danger)),
                            ),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Admin email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) => (value ?? '').contains('@') ? null : 'Enter your admin email.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty ? 'Enter your password.' : null,
                          ),
                          if (_showServer) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _server,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Server URL',
                                prefixIcon: Icon(Icons.dns_outlined),
                                helperText: 'Where the EventBook backend is running.',
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Sign in'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() => _showServer = !_showServer),
                            icon: const Icon(Icons.settings_ethernet, size: 18),
                            label: Text(_showServer ? 'Hide server settings' : 'Server: ${AdminApi.instance.baseUrl}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
