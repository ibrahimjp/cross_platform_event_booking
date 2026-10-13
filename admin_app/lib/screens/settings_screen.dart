import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PlatformSettings? _settings;
  Json? _system;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AdminApi.instance.get('/api/admin/settings'),
        AdminApi.instance.get('/api/admin/system'),
      ]);
      if (mounted) {
        setState(() {
          _settings = PlatformSettings.fromJson(results[0]['settings'] as Json?);
          _system = results[1];
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _save(Json changes, String message) async {
    final ok = await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/settings', changes),
      success: message,
    );
    if (ok) _load();
  }

  Future<void> _addCategory() async {
    final name = await promptText(
      context,
      title: 'Add category',
      label: 'Category name',
      minLength: 2,
      confirmLabel: 'Add',
    );
    if (name == null) return;
    await _save({
      'categories': [..._settings!.categories, name],
    }, 'Category added.');
  }

  Future<void> _removeCategory(String category) async {
    if (_settings!.categories.length <= 1) {
      toast(context, 'Keep at least one category.', error: true);
      return;
    }
    await _save({
      'categories': _settings!.categories.where((item) => item != category).toList(),
    }, 'Removed "$category". Existing events keep their category.');
  }

  Future<void> _changePassword() async {
    final current = await promptText(
      context,
      title: 'Current password',
      label: 'Current password',
      obscure: true,
      confirmLabel: 'Next',
    );
    if (current == null || !mounted) return;
    final next = await promptText(
      context,
      title: 'New password',
      label: 'New password',
      obscure: true,
      minLength: 8,
      helper: 'Your other admin sessions will be signed out.',
      confirmLabel: 'Change password',
    );
    if (next == null || !mounted) return;
    await runAction(
      context,
      () => SessionScope.of(context).changePassword(current, next),
      success: 'Password changed.',
    );
  }

  Future<void> _changeServer() async {
    final url = await promptText(
      context,
      title: 'Server URL',
      label: 'Backend address',
      initial: AdminApi.instance.baseUrl,
      helper: 'Changing the server signs you out.',
      confirmLabel: 'Switch',
    );
    if (url == null || !mounted) return;
    final session = SessionScope.of(context);
    await AdminApi.instance.setBaseUrl(url);
    await session.signOut(message: 'Sign in to ${AdminApi.instance.baseUrl}.');
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: sectionAppBar(
        context,
        'Platform & settings',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: settings == null
          ? (_error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load))
          : PageBody(
              maxWidth: 900,
              onRefresh: _load,
              children: [
                SectionCard(
                  title: 'Customer app controls',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.shopping_cart_outlined,
                          color: settings.salesPaused ? Tone.danger : Tone.success,
                        ),
                        title: const Text('Ticket sales'),
                        subtitle: Text(
                          settings.salesPaused
                              ? 'Paused: customers see "Ticket sales are temporarily paused" at checkout.'
                              : 'Live: customers can buy tickets.',
                        ),
                        value: !settings.salesPaused,
                        onChanged: (value) =>
                            _save({'salesPaused': !value}, value ? 'Ticket sales resumed.' : 'Ticket sales paused.'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.person_add_alt,
                          color: settings.registrationsOpen ? Tone.success : Tone.danger,
                        ),
                        title: const Text('New sign-ups'),
                        subtitle: Text(
                          settings.registrationsOpen ? 'Anyone can create an account.' : 'Registration is closed.',
                        ),
                        value: settings.registrationsOpen,
                        onChanged: (value) =>
                            _save({'registrationsOpen': value}, value ? 'Sign-ups opened.' : 'Sign-ups closed.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Event categories',
                  trailing: TextButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in settings.categories)
                        InputChip(label: Text(category), onDeleted: () => _removeCategory(category)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_system != null) _SystemCard(system: _system!),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Your admin account',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(name: session.admin?.name ?? '', url: session.admin?.avatarUrl ?? ''),
                        title: Text(session.admin?.name ?? ''),
                        subtitle: Text(session.admin?.email ?? ''),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.password),
                        title: const Text('Change password'),
                        onTap: _changePassword,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.dns_outlined),
                        title: const Text('Server'),
                        subtitle: Text(AdminApi.instance.baseUrl),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _changeServer,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout, color: Tone.danger),
                        title: const Text('Sign out', style: TextStyle(color: Tone.danger)),
                        onTap: () => session.signOut(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.system});

  final Json system;

  @override
  Widget build(BuildContext context) {
    final database = system['database'] as Json;
    final counts = database['counts'] as Json;
    final stripe = system['stripe'] as Json;
    final cloudinary = system['cloudinary'] as Json;
    final server = system['server'] as Json;
    final uptime = Duration(seconds: asInt(server['uptimeSeconds']));
    Widget status(String label, bool ok, String detail) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? Tone.success : Tone.warning),
      title: Text(label),
      subtitle: Text(detail),
    );
    return SectionCard(
      title: 'System status',
      child: Column(
        children: [
          status(
            'Database',
            database['connected'] == true,
            '${database['name']} · ${counts['users']} users, ${counts['events']} events, '
                '${counts['bookings']} bookings, ${counts['promos']} promos, ${counts['logs']} log entries',
          ),
          status(
            'Stripe payments',
            stripe['configured'] == true,
            stripe['configured'] == true
                ? '${(stripe['mode'] as String).toUpperCase()} mode · webhook ${stripe['webhook'] == true ? 'configured' : 'not configured (app confirms directly)'}'
                : 'Not configured: paid checkout is unavailable',
          ),
          status(
            'Cloudinary images',
            cloudinary['configured'] == true,
            cloudinary['configured'] == true ? 'Uploads enabled' : 'Not configured: use image URLs instead of uploads',
          ),
          status(
            'API server',
            true,
            'Node ${server['node']} · up ${uptime.inHours}h ${uptime.inMinutes % 60}m · started ${dateTime(asDate(server['startedAt']))}',
          ),
        ],
      ),
    );
  }
}
