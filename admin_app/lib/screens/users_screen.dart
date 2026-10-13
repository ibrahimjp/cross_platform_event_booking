import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'shell.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _filters = {'': 'Everyone', 'user': 'Customers', 'admin': 'Admins', 'blocked': 'Suspended'};
  static const _sorts = {'newest': 'Newest', 'oldest': 'Oldest', 'name': 'Name A–Z', 'lastLogin': 'Last active'};

  Paged<AdminUser>? _page;
  String? _error;
  String _query = '';
  String _filter = '';
  String _sort = 'newest';
  int _pageNumber = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/users', {
        'q': _query,
        'role': _filter == 'user' || _filter == 'admin' ? _filter : null,
        'status': _filter == 'blocked' ? 'blocked' : null,
        'sort': _sort,
        'page': _pageNumber,
      });
      if (mounted) {
        setState(() {
          _page = Paged.fromJson(data, 'users', AdminUser.fromJson);
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _reload({int page = 1}) {
    setState(() {
      _pageNumber = page;
      _page = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      appBar: sectionAppBar(
        context,
        'Users',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _reload(page: _pageNumber),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final user = await showDialog<AdminUser>(context: context, builder: (_) => const _CreateUserDialog());
          if (user != null && context.mounted) {
            toast(context, 'Created ${user.email}.');
            _reload();
          }
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New user'),
      ),
      body: PageBody(
        onRefresh: _load,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: 'Search name, email, phone or city',
                  onSubmitted: (value) {
                    _query = value;
                    _reload();
                  },
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (value) {
                  _sort = value;
                  _reload();
                },
                itemBuilder: (_) => [
                  for (final entry in _sorts.entries) PopupMenuItem(value: entry.key, child: Text(entry.value)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilterBar<String>(
            options: _filters,
            value: _filter,
            onChanged: (value) {
              _filter = value;
              _reload();
            },
          ),
          const SizedBox(height: 12),
          if (page == null)
            _error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load)
          else ...[
            if (page.items.isEmpty)
              const MessageView(icon: Icons.person_search, message: 'No users match.')
            else
              Card(
                child: Column(
                  children: [
                    for (final user in page.items) ...[
                      ListTile(
                        onTap: () => openUser(context, user.id, onChanged: _load),
                        leading: UserAvatar(name: user.name, url: user.avatarUrl),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ...userBadges(user),
                          ],
                        ),
                        subtitle: Text(
                          [
                            user.email,
                            if (user.city.isNotEmpty) user.city,
                            'joined ${dateShort(user.createdAt)}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: wide && user.stats != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    money(user.stats!.totalSpent),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${user.stats!.bookings} bookings · ${user.stats!.eventsHosted} hosted',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                      if (user != page.items.last) const Divider(),
                    ],
                  ],
                ),
              ),
            Pager(
              page: page.page,
              pages: page.pages,
              total: page.total,
              onPage: (value) => _reload(page: value),
            ),
          ],
        ],
      ),
    );
  }
}

List<Widget> userBadges(AdminUser user) => [
  if (user.isAdmin)
    const Padding(
      padding: EdgeInsets.only(right: 4),
      child: StatusChip('Admin', color: Tone.warning, icon: Icons.shield),
    ),
  if (user.isBlocked) const StatusChip('Suspended', color: Tone.danger, icon: Icons.block),
];

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  String _role = 'user';
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _phone, _city]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final data = await AdminApi.instance.post('/api/admin/users', {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'role': _role,
      });
      if (mounted) Navigator.pop(context, AdminUser.fromJson(data['user'] as Json));
    } on ApiException catch (error) {
      if (mounted) toast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create account'),
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
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a name.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => (value ?? '').contains('@') ? null : 'Enter a valid email.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'At least 8 characters.',
                  ),
                  validator: (value) => (value ?? '').length < 8 ? 'At least 8 characters.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City (optional)'),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'user', label: Text('Customer'), icon: Icon(Icons.person_outline)),
                    ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.shield_outlined)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (value) => setState(() => _role = value.first),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Create')),
      ],
    );
  }
}
