import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'booking_detail.dart';
import 'bookings_screen.dart';
import 'event_detail_screen.dart';
import 'users_screen.dart';

Future<void> openUser(BuildContext context, String id, {VoidCallback? onChanged}) async {
  final changed = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => UserDetailScreen(userId: id)));
  if (changed == true) onChanged?.call();
}

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  AdminUser? _user;
  List<Booking> _bookings = const [];
  List<AdminEvent> _events = const [];
  List<Json> _wishlist = const [];
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/users/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _user = AdminUser.fromJson(data['user'] as Json);
        _bookings = (data['bookings'] as List).map((b) => Booking.fromJson(b as Json)).toList();
        _events = (data['events'] as List).map((e) => AdminEvent.fromJson(e as Json)).toList();
        _wishlist = (data['wishlist'] as List).cast<Json>();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _update(Json changes, String message) async {
    final ok = await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/users/${widget.userId}', changes),
      success: message,
    );
    if (ok) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _suspend() async {
    final reason = await promptText(
      context,
      title: 'Suspend ${_user!.name}?',
      label: 'Reason (kept in the activity log)',
      helper: 'They are signed out everywhere immediately and cannot sign in or book until reinstated.',
      confirmLabel: 'Suspend',
    );
    if (reason == null) return;
    await _update({'isBlocked': true, 'blockedReason': reason}, 'Account suspended.');
  }

  Future<void> _resetPassword() async {
    final password = await promptText(
      context,
      title: 'Set a new password',
      label: 'New password',
      helper: 'Share it with the user securely. All their sessions are signed out.',
      minLength: 8,
      confirmLabel: 'Set password',
    );
    if (password == null || !mounted) return;
    await runAction(
      context,
      () => AdminApi.instance.post('/api/admin/users/${widget.userId}/password', {'password': password}),
      success: 'Password updated.',
    );
  }

  Future<void> _signOutEverywhere() async {
    if (!await confirmAction(
      context,
      title: 'Sign out everywhere?',
      message: 'Every device signed in as ${_user!.email} must sign in again.',
    )) {
      return;
    }
    if (!mounted) return;
    await runAction(
      context,
      () => AdminApi.instance.post('/api/admin/users/${widget.userId}/sign-out'),
      success: 'All sessions ended.',
    );
  }

  Future<void> _delete() async {
    final user = _user!;
    if (!await confirmAction(
      context,
      title: 'Delete ${user.name}?',
      message: 'The account is removed permanently. Past bookings stay in reports as "Deleted user".',
      confirmLabel: 'Delete account',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    try {
      await AdminApi.instance.delete('/api/admin/users/${user.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode != 409) {
        toast(context, error.message, error: true);
        return;
      }
      final force = await confirmAction(
        context,
        title: 'Cancel their bookings and events too?',
        message:
            '${error.message}\n\nUpcoming bookings are cancelled and refunded, and hosted events are deleted '
            'after refunding their attendees.',
        confirmLabel: 'Delete everything',
        destructive: true,
      );
      if (!force || !mounted) return;
      final ok = await runAction(
        context,
        () => AdminApi.instance.delete('/api/admin/users/${user.id}', {'force': 'true'}),
      );
      if (!ok) return;
    }
    if (mounted) {
      toast(context, 'Account deleted.');
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(user: _user!),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isSelf = user != null && user.id == SessionScope.of(context).admin?.id;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(user?.name ?? 'User'),
          actions: [
            if (user != null)
              PopupMenuButton<String>(
                tooltip: 'Account actions',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _edit();
                    case 'password':
                      _resetPassword();
                    case 'signout':
                      _signOutEverywhere();
                    case 'role':
                      _update({
                        'role': user.isAdmin ? 'user' : 'admin',
                      }, user.isAdmin ? 'Admin access removed.' : '${user.name} is now an admin.');
                    case 'block':
                      user.isBlocked ? _update({'isBlocked': false}, 'Account reinstated.') : _suspend();
                    case 'delete':
                      _delete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit profile')),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: ListTile(leading: Icon(Icons.password), title: Text('Reset password')),
                  ),
                  const PopupMenuItem(
                    value: 'signout',
                    child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out everywhere')),
                  ),
                  if (!isSelf) ...[
                    PopupMenuItem(
                      value: 'role',
                      child: ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(user.isAdmin ? 'Remove admin access' : 'Make admin'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: ListTile(
                        leading: Icon(
                          user.isBlocked ? Icons.lock_open : Icons.block,
                          color: user.isBlocked ? null : Tone.danger,
                        ),
                        title: Text(user.isBlocked ? 'Reinstate account' : 'Suspend account'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_forever_outlined, color: Tone.danger),
                        title: Text('Delete account', style: TextStyle(color: Tone.danger)),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: user == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  if (await showCompTicketDialog(context, user: user)) {
                    _changed = true;
                    _load();
                  }
                },
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Gift tickets'),
              ),
        body: user == null
            ? (_error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load))
            : _body(context, user),
      ),
    );
  }

  Widget _body(BuildContext context, AdminUser user) {
    final theme = Theme.of(context);
    final stats = user.stats ?? UserStats(bookings: 0, totalSpent: 0, eventsHosted: 0);
    return PageBody(
      onRefresh: _load,
      maxWidth: 1100,
      children: [
        if (user.isBlocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MaterialBanner(
              backgroundColor: Tone.danger.withValues(alpha: 0.1),
              leading: const Icon(Icons.block, color: Tone.danger),
              content: Text('Suspended${user.blockedReason.isEmpty ? '' : ': ${user.blockedReason}'}'),
              actions: [
                TextButton(
                  onPressed: () => _update({'isBlocked': false}, 'Account reinstated.'),
                  child: const Text('Reinstate'),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                UserAvatar(name: user.name, url: user.avatarUrl, radius: 34),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(user.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          ...userBadges(user),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(user.email),
                      const SizedBox(height: 4),
                      Text(
                        'Joined ${dateShort(user.createdAt)} · last sign-in ${timeAgo(user.lastLoginAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            KpiCard(
              label: 'Lifetime spend',
              value: money(stats.totalSpent),
              icon: Icons.payments_outlined,
              color: Tone.success,
            ),
            KpiCard(label: 'Bookings', value: '${stats.bookings}', icon: Icons.confirmation_number_outlined),
            KpiCard(
              label: 'Events hosted',
              value: '${stats.eventsHosted}',
              icon: Icons.event_outlined,
              color: Tone.info,
            ),
            KpiCard(label: 'Wishlist', value: '${user.wishlistCount}', icon: Icons.favorite_border, color: Tone.danger),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Profile',
          trailing: TextButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          child: Column(
            children: [
              InfoRow('Phone', user.phone),
              InfoRow('City', user.city),
              InfoRow('Interests', user.preferredCategories.join(', ')),
              InfoRow('Notifications', user.notificationsEnabled ? 'On' : 'Off'),
              InfoRow('Stripe customer', user.hasStripeCustomer ? 'Yes' : 'No'),
              InfoRow('User ID', user.id),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Bookings (${_bookings.length})',
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: _bookings.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No bookings.')),
                )
              : Column(
                  children: [
                    for (final booking in _bookings)
                      BookingTile(
                        booking: booking,
                        showUser: false,
                        onTap: () async {
                          if (await showBookingDetail(context, booking.id)) {
                            _changed = true;
                            _load();
                          }
                        },
                      ),
                  ],
                ),
        ),
        if (_events.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Hosted events (${_events.length})',
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Column(
              children: [
                for (final event in _events)
                  ListTile(
                    leading: EventThumb(url: event.imageUrl, size: 42),
                    title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${dateShort(event.startsAt)} · ${event.stats?.ticketsSold ?? 0} sold'),
                    trailing: Text(
                      money(event.stats?.revenue ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => openEvent(context, event.id, onChanged: _load),
                  ),
              ],
            ),
          ),
        ],
        if (_wishlist.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Wishlist',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _wishlist)
                  ActionChip(
                    avatar: const Icon(Icons.favorite, size: 16, color: Tone.danger),
                    label: Text(item['title'] as String),
                    onPressed: () => openEvent(context, item['id'] as String),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user});

  final AdminUser user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _city = TextEditingController(text: widget.user.city);
  late final _interests = TextEditingController(text: widget.user.preferredCategories.join(', '));
  late bool _notifications = widget.user.notificationsEnabled;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _city, _interests]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/users/${widget.user.id}', {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'notificationsEnabled': _notifications,
        'preferredCategories': _interests.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      }),
      success: 'Profile updated.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a name.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => (value ?? '').contains('@') ? null : 'Enter a valid email.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _interests,
                  decoration: const InputDecoration(labelText: 'Interests', helperText: 'Comma-separated categories.'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifications'),
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
