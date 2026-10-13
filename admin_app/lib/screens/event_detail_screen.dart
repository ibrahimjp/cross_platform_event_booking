import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'booking_detail.dart';
import 'bookings_screen.dart';
import 'event_form_screen.dart';
import 'events_screen.dart';
import 'user_detail_screen.dart';

Future<void> openEvent(BuildContext context, String id, {VoidCallback? onChanged}) async {
  final changed = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id)));
  if (changed == true) onChanged?.call();
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  AdminEvent? _event;
  List<Booking> _bookings = const [];
  String? _error;
  bool _changed = false;
  bool _showCancelled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/events/${widget.eventId}');
      if (!mounted) return;
      setState(() {
        _event = AdminEvent.fromJson(data['event'] as Json);
        _bookings = (data['bookings'] as List).map((b) => Booking.fromJson(b as Json)).toList();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _markChanged() {
    _changed = true;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(event?.title ?? 'Event'),
          actions: [
            if (event != null) ...[
              IconButton(
                tooltip: 'Edit event',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final saved = await Navigator.of(context)
                      .push<AdminEvent>(MaterialPageRoute(builder: (_) => EventFormScreen(event: event)));
                  if (saved != null) _markChanged();
                },
              ),
              EventActionsMenu(event: event, onChanged: _markChanged, onDeleted: () => Navigator.of(context).pop(true)),
            ],
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: event == null || event.isPast
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  if (await showCompTicketDialog(context, event: event)) _markChanged();
                },
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Comp tickets'),
              ),
        body: event == null
            ? (_error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load))
            : _body(context, event),
      ),
    );
  }

  Widget _body(BuildContext context, AdminEvent event) {
    final theme = Theme.of(context);
    final stats = event.stats ?? EventStats(bookings: 0, ticketsSold: 0, revenue: 0);
    final visibleBookings = _showCancelled ? _bookings : _bookings.where((b) => !b.isCancelled).toList();
    final capacity = event.ticketCategories.fold<int>(0, (sum, t) => sum + t.remaining) + stats.ticketsSold;
    return PageBody(
      onRefresh: _load,
      maxWidth: 1100,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (event.imageUrl.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Image.network(
                    event.imageUrl,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip(event.category, color: brand),
                        ...eventBadges(event),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(event.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${dateTime(event.startsAt)} → ${dateTime(event.endsAt)}  (${event.time})'),
                    Text('${event.venue}, ${event.location}', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: event.hostId.isEmpty ? null : () => openUser(context, event.hostId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Hosted by ${event.hostName.isEmpty ? 'unknown' : event.hostName}',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            KpiCard(label: 'Revenue', value: money(stats.revenue), icon: Icons.payments_outlined, color: Tone.success),
            KpiCard(
              label: 'Tickets sold',
              value: '${stats.ticketsSold}',
              icon: Icons.confirmation_number_outlined,
              caption: capacity == 0 ? null : '${(stats.ticketsSold / capacity * 100).round()}% of $capacity',
            ),
            KpiCard(label: 'Bookings', value: '${stats.bookings}', icon: Icons.receipt_long_outlined, color: Tone.info),
            KpiCard(label: 'Wishlisted', value: '${stats.wishlisted}', icon: Icons.favorite_border, color: Tone.danger),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Ticket inventory',
          child: Column(
            children: [
              for (final ticket in event.ticketCategories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ticket.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(ticket.description.isEmpty ? ticket.id : ticket.description),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ticket.price == 0 ? 'Free' : money(ticket.price),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${ticket.remaining} left',
                        style: TextStyle(
                          color: ticket.remaining == 0
                              ? Tone.danger
                              : ticket.remaining <= 10
                              ? Tone.warning
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(event.description),
              const SizedBox(height: 12),
              InfoRow('Lineup', event.lineup.join(', ')),
              InfoRow('Starting price', money(event.priceStarting)),
              InfoRow('AI match', '${event.matchPercentage}%'),
              InfoRow('AI reason', event.aiReason),
              InfoRow('Shown attendees', count(event.attendeeCount)),
              InfoRow('Event ID', event.id),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Attendees & bookings (${_bookings.length})',
          trailing: FilterChip(
            label: const Text('Show cancelled'),
            selected: _showCancelled,
            onSelected: (value) => setState(() => _showCancelled = value),
          ),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: visibleBookings.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No bookings yet.')),
                )
              : Column(
                  children: [
                    for (final booking in visibleBookings)
                      BookingTile(
                        booking: booking,
                        showEvent: false,
                        onTap: () async {
                          if (await showBookingDetail(context, booking.id)) _markChanged();
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
