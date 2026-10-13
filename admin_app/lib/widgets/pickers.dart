import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import 'common.dart';

/// Searchable picker for a user account.
Future<AdminUser?> pickUser(BuildContext context, {String title = 'Choose a user'}) {
  return showDialog<AdminUser>(
    context: context,
    builder: (context) => _SearchPicker<AdminUser>(
      title: title,
      hint: 'Search name or email',
      load: (query) async {
        final data = await AdminApi.instance.get('/api/admin/users', {'q': query, 'limit': 30});
        return Paged.fromJson(data, 'users', AdminUser.fromJson).items;
      },
      tile: (user) => ListTile(
        leading: UserAvatar(name: user.name, url: user.avatarUrl),
        title: Text(user.name),
        subtitle: Text(user.email),
        trailing: user.isAdmin ? const StatusChip('Admin') : null,
      ),
    ),
  );
}

/// Searchable picker for an event.
Future<AdminEvent?> pickEvent(BuildContext context, {String title = 'Choose an event'}) {
  return showDialog<AdminEvent>(
    context: context,
    builder: (context) => _SearchPicker<AdminEvent>(
      title: title,
      hint: 'Search events',
      load: (query) async {
        final data = await AdminApi.instance.get('/api/admin/events', {
          'q': query,
          'limit': 30,
          'sort': 'soonest',
          'status': 'upcoming',
        });
        return Paged.fromJson(data, 'events', AdminEvent.fromJson).items;
      },
      tile: (event) => ListTile(
        leading: EventThumb(url: event.imageUrl, size: 40),
        title: Text(event.title),
        subtitle: Text('${dateShort(event.startsAt)} · ${event.remainingTickets} tickets left'),
      ),
    ),
  );
}

class _SearchPicker<T> extends StatefulWidget {
  const _SearchPicker({required this.title, required this.hint, required this.load, required this.tile});

  final String title;
  final String hint;
  final Future<List<T>> Function(String query) load;
  final Widget Function(T item) tile;

  @override
  State<_SearchPicker<T>> createState() => _SearchPickerState<T>();
}

class _SearchPickerState<T> extends State<_SearchPicker<T>> {
  List<T>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _items = null);
    try {
      final items = await widget.load(query);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _items = [];
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            SearchField(hint: widget.hint, onSubmitted: _search),
            const SizedBox(height: 8),
            Expanded(
              child: items == null
                  ? const LoadingView()
                  : items.isEmpty
                  ? MessageView(icon: Icons.search_off, message: _error ?? 'Nothing found.')
                  : ListView(
                      children: [
                        for (final item in items)
                          InkWell(
                            onTap: () => Navigator.pop(context, item),
                            child: IgnorePointer(child: widget.tile(item)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
