import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'booking_detail.dart';
import 'event_detail_screen.dart';
import 'shell.dart';
import 'user_detail_screen.dart';

/// Audit trail of every action taken in the admin panel.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _filters = {
    '': 'Everything',
    'event.': 'Events',
    'booking.': 'Bookings',
    'user.': 'Users',
    'promo.': 'Promos',
    'settings.': 'Settings',
    'admin.': 'Admin sign-ins',
  };

  Paged<AdminLogEntry>? _page;
  String? _error;
  String _filter = '';
  String _query = '';
  int _pageNumber = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/logs', {
        'action': _filter,
        'q': _query,
        'page': _pageNumber,
      });
      if (mounted) {
        setState(() {
          _page = Paged.fromJson(data, 'logs', AdminLogEntry.fromJson);
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

  (IconData, Color) _style(String action) {
    if (action.endsWith('.delete') || action == 'user.suspend') return (Icons.delete_outline, Tone.danger);
    if (action.endsWith('.cancel')) return (Icons.cancel_outlined, Tone.danger);
    if (action.endsWith('.create') || action == 'booking.comp' || action == 'event.duplicate') {
      return (Icons.add_circle_outline, Tone.success);
    }
    if (action.startsWith('settings')) return (Icons.tune, Tone.warning);
    if (action.startsWith('admin.')) return (Icons.login, Tone.info);
    return (Icons.edit_outlined, brand);
  }

  void _open(AdminLogEntry entry) {
    if (entry.targetId.isEmpty || entry.action.endsWith('.delete')) return;
    switch (entry.targetType) {
      case 'event':
        openEvent(context, entry.targetId);
      case 'user':
        openUser(context, entry.targetId);
      case 'booking':
        showBookingDetail(context, entry.targetId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: sectionAppBar(
        context,
        'Activity log',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _reload(page: _pageNumber),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PageBody(
        onRefresh: _load,
        children: [
          SearchField(
            hint: 'Search activity or admin name',
            onSubmitted: (value) {
              _query = value;
              _reload();
            },
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
              const MessageView(icon: Icons.history, message: 'No admin activity recorded yet.')
            else
              Card(
                child: Column(
                  children: [
                    for (final entry in page.items) ...[
                      Builder(
                        builder: (context) {
                          final (icon, color) = _style(entry.action);
                          return ListTile(
                            onTap: () => _open(entry),
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(entry.summary),
                            subtitle: Text('${entry.adminName} · ${entry.action} · ${dateTime(entry.createdAt)}'),
                          );
                        },
                      ),
                      if (entry != page.items.last) const Divider(),
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
