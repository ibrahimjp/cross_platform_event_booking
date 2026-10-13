import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'event_form_screen.dart';
import 'hosted_events_screen.dart';
import 'saved_payment_methods_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _avatarBusy = false;

  Future<void> _changeAvatar(AppState appState) async {
    final hasPhoto = appState.user?.avatarUrl.isNotEmpty ?? false;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
              title: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
              onTap: () => Navigator.pop(sheetContext, 'upload'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    ImageUpload? image;
    if (action == 'upload') {
      image = await pickImage(context);
      if (image == null) return;
    }
    setState(() => _avatarBusy = true);
    try {
      if (image != null) {
        await appState.uploadAvatar(image);
        if (mounted) showMessage(context, 'Profile photo updated.');
      } else {
        await appState.removeAvatar();
        if (mounted) showMessage(context, 'Profile photo removed.');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold))),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await appState.refreshUser();
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _avatarBusy ? null : () => _changeAvatar(appState),
                    child: Stack(
                      children: [
                        UserAvatar(name: user.name, url: user.avatarUrl, radius: 38),
                        if (_avatarBusy)
                          const Positioned.fill(
                            child: CircleAvatar(backgroundColor: Colors.black38, child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                        if (user.phone.isNotEmpty) Text(user.phone, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        if (user.city.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 12, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(user.city, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _CountTile(label: 'Bookings', value: appState.upcomingBookings.length + appState.pastBookings.length, onTap: () => appState.setNavIndex(3)),
                const SizedBox(width: 10),
                _CountTile(
                  label: 'Wishlist',
                  value: appState.wishlistEvents.length,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
                ),
                const SizedBox(width: 10),
                _CountTile(
                  label: 'Hosted',
                  value: appState.events.where(appState.isHost).length,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostedEventsScreen())),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Section(title: 'Host', children: [
              _tile(Icons.add_circle_outline, 'Host an Event', 'List your event and sell tickets',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventFormScreen()))),
              _tile(Icons.storefront_outlined, 'My Hosted Events', 'Sales, attendees, edit or delete',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostedEventsScreen()))),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'Account', children: [
              _tile(Icons.person_outline, 'Personal Information', 'Name, email, phone, city',
                  () => showDialog<void>(context: context, builder: (_) => const _PersonalInfoDialog())),
              _tile(Icons.lock_outline, 'Change Password', 'Update your sign-in password',
                  () => showDialog<void>(context: context, builder: (_) => const _ChangePasswordDialog())),
              _tile(Icons.payment_outlined, 'Saved Payment Methods', 'Cards stored securely by Stripe',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPaymentMethodsScreen()))),
              _tile(Icons.favorite_outline, 'Wishlist', '${appState.wishlistEvents.length} saved events',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'Preferences', children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined, color: AppTheme.primary),
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                value: appState.isDarkMode,
                onChanged: (_) => appState.toggleTheme(),
              ),
              _tile(Icons.psychology_outlined, 'AI Preferences',
                  user.preferredCategories.isEmpty ? 'Choose categories you like' : user.preferredCategories.join(', '),
                  () => _editAiPreferences(appState)),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_none_outlined, color: AppTheme.primary),
                title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Booking alerts & recommendations', style: TextStyle(fontSize: 12)),
                value: user.notificationsEnabled,
                onChanged: (value) async {
                  try {
                    await appState.setNotificationsEnabled(value);
                  } catch (error) {
                    if (context.mounted) showMessage(context, errorText(error), error: true);
                  }
                },
              ),
              _tile(Icons.dns_outlined, 'Server Address', ApiService.baseUrl, () async {
                await showServerSettingsDialog(context);
                if (mounted) setState(() {});
              }),
              _tile(Icons.help_outline, 'Support & FAQ', 'Tickets, payments and refunds', () => _showSupport(context)),
            ]),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: appState.logout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Future<void> _editAiPreferences(AppState appState) async {
    final selected = List<String>.of(appState.user?.preferredCategories ?? const []);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('AI Preferences'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: eventCategories
                  .map((category) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(category),
                        value: selected.contains(category),
                        onChanged: (checked) => setDialogState(() => checked == true ? selected.add(category) : selected.remove(category)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await appState.setPreferredCategories(result);
      if (mounted) showMessage(context, 'Preferences saved. Your recommendations have been updated.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  void _showSupport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Support & FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How do I get my ticket?', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Confirmed bookings and QR tickets appear in My Bookings.'),
              SizedBox(height: 12),
              Text('Can I cancel?', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Yes, cancel an upcoming booking from My Bookings. Paid bookings are refunded to your card through Stripe.'),
              SizedBox(height: 12),
              Text('How do I host an event?', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Tap "Host an Event", fill in the details and ticket types, then publish. Manage sales from My Hosted Events.'),
              SizedBox(height: 12),
              Text('How are card details stored?', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Card details are handled by Stripe and are never stored by EventBook.'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value, required this.onTap});

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              children: [
                Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.outline, letterSpacing: 0.8)),
        ),
        Container(
          decoration: AppTheme.cardDecoration(context),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonalInfoDialog extends StatefulWidget {
  const _PersonalInfoDialog();

  @override
  State<_PersonalInfoDialog> createState() => _PersonalInfoDialogState();
}

class _PersonalInfoDialogState extends State<_PersonalInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user!;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _phone = TextEditingController(text: user.phone);
    _city = TextEditingController(text: user.city);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().updateProfile(name: _name.text, email: _email.text, phone: _phone.text, city: _city.text);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Profile updated.');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personal Information'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => value == null || value.trim().length < 2 ? 'Enter your name.' : null,
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? 'Enter a valid email.' : null,
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) => (value?.length ?? 0) > 30 ? 'Phone number is too long.' : null,
              ),
              TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'City (used for "Near Me")'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().changePassword(_current.text, _next.text);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Password changed.');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (value) => value == null || value.isEmpty ? 'Enter your current password.' : null,
            ),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters.' : null,
            ),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              validator: (value) => value != _next.text ? 'Passwords do not match.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
