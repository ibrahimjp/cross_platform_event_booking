import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'shell.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _filters = {
    'all': 'All',
    'upcoming': 'Upcoming',
    'past': 'Past',
    'hidden': 'Hidden',
    'trending': 'Trending',
  };
  static const _sorts = {
    'latest': 'Latest date first',
    'soonest': 'Soonest first',
    'newest': 'Recently created',
    'title': 'Title A–Z',
  };

  Paged<AdminEvent>? _page;
  String? _error;
  String _query = '';
  String _status = 'all';
  String _sort = 'latest';
  String _category = '';
  List<String> _categories = const [];
  int _pageNumber = 1;

  @override
  void initState() {
    super.initState();
    _load();
    AdminApi.instance
        .get('/api/admin/settings')
        .then((data) {
          if (mounted) setState(() => _categories = PlatformSettings.fromJson(data['settings'] as Json?).categories);
        })
        .catchError((_) {});
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/events', {
        'q': _query,
        'status': _status == 'all' ? '' : _status,
        'category': _category,
        'sort': _sort,
        'page': _pageNumber,
        'limit': 20,
      });
      if (mounted) {
        setState(() {
          _page = Paged.fromJson(data, 'events', AdminEvent.fromJson);
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
    return Scaffold(
      appBar: sectionAppBar(
        context,
        'Events',
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
          final created = await Navigator.of(context)
              .push<AdminEvent>(MaterialPageRoute(builder: (_) => const EventFormScreen()));
          if (created != null) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
      body: PageBody(
        onRefresh: _load,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: 'Search title, venue or city',
                  onSubmitted: (value) {
                    _query = value;
                    _reload();
                  },
                ),
              ),
              const SizedBox(width: 8),
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
              if (_categories.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Category',
                  icon: Badge(isLabelVisible: _category.isNotEmpty, child: const Icon(Icons.category_outlined)),
                  initialValue: _category,
                  onSelected: (value) {
                    _category = value;
                    _reload();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '', child: Text('All categories')),
                    for (final category in _categories) PopupMenuItem(value: category, child: Text(category)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilterBar<String>(
            options: _filters,
            value: _status,
            onChanged: (value) {
              _status = value;
              _reload();
            },
          ),
          const SizedBox(height: 12),
          if (page == null)
            _error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load)
          else ...[
            if (page.items.isEmpty)
              const MessageView(icon: Icons.event_busy, message: 'No events match these filters.')
            else
              Card(
                child: Column(
                  children: [
                    for (final event in page.items) ...[
                      _EventRow(event: event, onChanged: _load),
                      if (event != page.items.last) const Divider(),
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onChanged});

  final AdminEvent event;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = event.stats;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return InkWell(
      onTap: () => openEvent(context, event.id, onChanged: onChanged),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            EventThumb(url: event.imageUrl, size: wide ? 64 : 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dateTime(event.startsAt)} · ${event.location} · ${event.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: eventBadges(event)),
                ],
              ),
            ),
            if (wide && stats != null)
              SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(stats.revenue),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${stats.ticketsSold} sold · ${event.remainingTickets} left',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Host: ${event.hostName.isEmpty ? '—' : event.hostName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            EventActionsMenu(event: event, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

List<Widget> eventBadges(AdminEvent event) => [
  if (event.isHidden) const StatusChip('Hidden', color: Tone.neutral, icon: Icons.visibility_off),
  if (event.isPast)
    const StatusChip('Ended', color: Tone.neutral)
  else
    const StatusChip('Upcoming', color: Tone.success),
  if (event.isTrending) const StatusChip('Trending', color: Tone.warning, icon: Icons.local_fire_department),
  if (event.isGarbaSpecial) const StatusChip('Garba special', color: brand),
  if (!event.isPast && event.remainingTickets == 0) const StatusChip('Sold out', color: Tone.danger),
];

/// Overflow menu with every quick action an admin can take on an event.
class EventActionsMenu extends StatelessWidget {
  const EventActionsMenu({super.key, required this.event, required this.onChanged, this.onDeleted});

  final AdminEvent event;
  final VoidCallback onChanged;
  final VoidCallback? onDeleted;

  Future<void> _flag(BuildContext context, String key, bool value, String message) async {
    final ok = await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/events/${event.id}/flags', {key: value}),
      success: message,
    );
    if (ok) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Event actions',
      onSelected: (action) async {
        switch (action) {
          case 'edit':
            final saved = await Navigator.of(context)
                .push<AdminEvent>(MaterialPageRoute(builder: (_) => EventFormScreen(event: event)));
            if (saved != null) onChanged();
          case 'visibility':
            await _flag(
              context,
              'isHidden',
              !event.isHidden,
              event.isHidden ? 'Event is visible to customers again.' : 'Event hidden from customers.',
            );
          case 'trending':
            await _flag(
              context,
              'isTrending',
              !event.isTrending,
              event.isTrending ? 'Removed from trending.' : 'Marked as trending.',
            );
          case 'garba':
            await _flag(context, 'isGarbaSpecial', !event.isGarbaSpecial, 'Garba special updated.');
          case 'duplicate':
            final ok = await runAction(
              context,
              () => AdminApi.instance.post('/api/admin/events/${event.id}/duplicate'),
              success: 'Duplicated as a hidden draft.',
            );
            if (ok) onChanged();
          case 'delete':
            if (context.mounted && await deleteEvent(context, event)) {
              (onDeleted ?? onChanged)();
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit')),
        ),
        PopupMenuItem(
          value: 'visibility',
          child: ListTile(
            leading: Icon(event.isHidden ? Icons.visibility : Icons.visibility_off_outlined),
            title: Text(event.isHidden ? 'Publish (show)' : 'Hide from customers'),
          ),
        ),
        PopupMenuItem(
          value: 'trending',
          child: ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(event.isTrending ? 'Remove trending' : 'Mark trending'),
          ),
        ),
        PopupMenuItem(
          value: 'garba',
          child: ListTile(
            leading: const Icon(Icons.celebration_outlined),
            title: Text(event.isGarbaSpecial ? 'Unset Garba special' : 'Set Garba special'),
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(leading: Icon(Icons.copy_outlined), title: Text('Duplicate')),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Tone.danger),
            title: Text('Delete', style: TextStyle(color: Tone.danger)),
          ),
        ),
      ],
    );
  }
}

/// Deletes an event, offering to cancel and refund its bookings when it has any.
Future<bool> deleteEvent(BuildContext context, AdminEvent event) async {
  final confirmed = await confirmAction(
    context,
    title: 'Delete "${event.title}"?',
    message: 'The event is removed from the app and from every wishlist. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  try {
    await AdminApi.instance.delete('/api/admin/events/${event.id}');
    if (context.mounted) toast(context, 'Event deleted.');
    return true;
  } on ApiException catch (error) {
    if (error.statusCode != 409 || !context.mounted) {
      if (context.mounted) toast(context, error.message, error: true);
      return false;
    }
    final force = await confirmAction(
      context,
      title: 'Event has active bookings',
      message:
          '${error.message}\n\nEvery active booking will be cancelled, paid ones refunded through Stripe, '
          'and then the event will be deleted.',
      confirmLabel: 'Cancel bookings & delete',
      destructive: true,
    );
    if (!force || !context.mounted) return false;
    return runAction(
      context,
      () => AdminApi.instance.delete('/api/admin/events/${event.id}', {'force': 'true'}),
      success: 'Bookings refunded and event deleted.',
    );
  }
}
