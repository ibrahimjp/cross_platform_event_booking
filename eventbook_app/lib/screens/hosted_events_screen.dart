import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';
import 'event_form_screen.dart';

class HostedEventsScreen extends StatefulWidget {
  const HostedEventsScreen({super.key});

  @override
  State<HostedEventsScreen> createState() => _HostedEventsScreenState();
}

class _HostedEventsScreenState extends State<HostedEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadHostedEvents());
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final events = appState.hostedEvents;
    final totalRevenue = events.fold<double>(0, (sum, e) => sum + (e.stats?.revenue ?? 0));
    final totalTickets = events.fold<int>(0, (sum, e) => sum + (e.stats?.ticketsSold ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('My Hosted Events', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-hosted-event',
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventFormScreen())),
      ),
      body: RefreshIndicator(
        onRefresh: appState.loadHostedEvents,
        child: appState.hostedLoading && events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  if (appState.hostedError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(appState.hostedError!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  Row(
                    children: [
                      _Stat(label: 'Events', value: '${events.length}'),
                      const SizedBox(width: 10),
                      _Stat(label: 'Tickets sold', value: '$totalTickets'),
                      const SizedBox(width: 10),
                      _Stat(label: 'Revenue', value: formatPrice(totalRevenue)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (events.isEmpty && !appState.hostedLoading)
                    const EmptyState(
                      icon: Icons.storefront_outlined,
                      message: 'You haven\'t hosted any events yet.\nTap "New Event" to list your first one.',
                    ),
                  ...events.map((event) => _HostedEventTile(event: event)),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary))),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _HostedEventTile extends StatelessWidget {
  const _HostedEventTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final stats = event.stats ?? const HostStats();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostedEventDetailScreen(event: event))),
          child: Row(
            children: [
              SizedBox(width: 100, height: 110, child: EventImage(event.imageUrl, iconSize: 26)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(event.hasEnded ? 'Ended · ${event.dateLabel}' : event.dateLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: event.hasEnded ? AppTheme.outline : AppTheme.primary)),
                      const SizedBox(height: 8),
                      Text('${stats.ticketsSold} sold · ${event.totalRemaining} left · ${formatPrice(stats.revenue)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class HostedEventDetailScreen extends StatefulWidget {
  const HostedEventDetailScreen({super.key, required this.event});

  final Event event;

  @override
  State<HostedEventDetailScreen> createState() => _HostedEventDetailScreenState();
}

class _HostedEventDetailScreenState extends State<HostedEventDetailScreen> {
  late Future<List<Attendee>> _attendees;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _attendees = context.read<AppState>().loadAttendees(widget.event.id);
  }

  void _reload() => setState(() => _attendees = context.read<AppState>().loadAttendees(widget.event.id));

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text('The event and its image will be permanently removed. Events with active bookings cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await context.read<AppState>().deleteEvent(widget.event.id);
      if (!mounted) return;
      showMessage(context, 'Event deleted.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final event = appState.hostedEvents.where((e) => e.id == widget.event.id).firstOrNull ??
        appState.eventById(widget.event.id) ??
        widget.event;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Event'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EventFormScreen(event: event)));
              if (saved == true) _reload();
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: _deleting
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await appState.loadHostedEvents();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(aspectRatio: 16 / 8, child: EventImage(event.imageUrl)),
            ),
            const SizedBox(height: 14),
            Text(event.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${event.fullDateLabel} · ${event.time}', style: Theme.of(context).textTheme.bodySmall),
            Text('${event.venue}, ${event.location}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => openEvent(context, event),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View public page'),
            ),
            const SizedBox(height: 16),
            const Text('Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...event.ticketCategories.map((ticket) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primary),
                  title: Text(ticket.name),
                  subtitle: Text(formatPrice(ticket.price)),
                  trailing: Text('${ticket.remaining} left', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(child: Text('Attendees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              ],
            ),
            FutureBuilder<List<Attendee>>(
              future: _attendees,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Text(errorText(snapshot.error!), style: const TextStyle(color: Colors.redAccent));
                }
                final attendees = snapshot.data!;
                if (attendees.isEmpty) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No bookings yet.'));
                }
                return Column(
                  children: attendees
                      .map((attendee) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(name: attendee.name, url: attendee.avatarUrl, radius: 20),
                            title: Text(attendee.name),
                            subtitle: Text(
                              '${attendee.email}\n${attendee.ticketCount} ticket(s) · ${DateFormat('MMM d, h:mm a').format(attendee.createdAt)}',
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatPrice(attendee.totalPaid), style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(attendee.status,
                                    style: TextStyle(fontSize: 11, color: attendee.status == 'Cancelled' ? Colors.red : Colors.green)),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
