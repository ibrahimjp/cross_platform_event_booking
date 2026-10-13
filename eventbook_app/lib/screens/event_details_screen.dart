import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';
import 'hosted_events_screen.dart';
import 'ticket_selection_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final event = appState.activeEvent;
    if (event == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy, message: 'This event is no longer available.'));
    }
    final isHost = appState.isHost(event);
    final canBook = !event.isSoldOut && !event.hasEnded;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: appState.loadEvents,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface), onPressed: () => Navigator.pop(context)),
                ),
              ),
              actions: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined, color: AppTheme.onSurface),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(
                        text: '${event.title}\n${event.fullDateLabel} · ${event.time}\n${event.venue}, ${event.location}\n'
                            'Tickets from ${formatPrice(event.priceStarting)} on EventBook',
                      ));
                      if (context.mounted) showMessage(context, 'Event details copied to clipboard.');
                    },
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 8), child: WishlistButton(event: event)),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventImage(event.imageUrl, iconSize: 64),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(event.category.toUpperCase(),
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text(
                          event.priceStarting == 0 ? 'Free RSVP' : '${formatPrice(event.priceStarting)} onwards',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(event.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2)),
                    if (event.hostName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Hosted by ${isHost ? 'you' : event.hostName}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 20),
                    _InfoCard(
                      icon: Icons.calendar_month,
                      title: event.fullDateLabel,
                      subtitle: event.time,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      icon: Icons.location_on,
                      title: event.venue,
                      subtitle: event.location,
                      actionLabel: 'View on Map',
                      onAction: () async {
                        final query = Uri.encodeComponent('${event.venue}, ${event.location}');
                        final opened = await openExternalUrl('https://www.google.com/maps/search/?api=1&query=$query');
                        if (!opened && context.mounted) showMessage(context, 'Could not open maps.', error: true);
                      },
                    ),
                    if (event.aiReason.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassDecoration(context),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('AI Concierge Note · ${appState.matchScore(event)}% match',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(event.aiReason, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text('About the Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(event.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
                    if (event.lineup.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Lineup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: event.lineup
                            .map((artist) => Chip(label: Text(artist), backgroundColor: AppTheme.subtle(context), side: BorderSide.none))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text('Tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...event.ticketCategories.map((ticket) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(ticket.name)),
                              Text(
                                ticket.remaining == 0 ? 'Sold out' : '${formatPrice(ticket.price)} · ${ticket.remaining} left',
                                style: TextStyle(fontWeight: FontWeight.w600, color: ticket.remaining == 0 ? Colors.red : null),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(context),
                      child: Row(
                        children: [
                          const Icon(Icons.groups_outlined, color: AppTheme.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.goingCount >= 1000
                                      ? '${(event.goingCount / 1000).toStringAsFixed(1)}k people going'
                                      : '${event.goingCount} ${event.goingCount == 1 ? 'person' : 'people'} going',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text('${event.ticketsSold} tickets booked on EventBook', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: AppTheme.barColor(context),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Starting at', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                  Text(formatPrice(event.priceStarting), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 16),
              if (isHost) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HostedEventDetailScreen(event: event)),
                  ),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Manage'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: GradientButton(
                  label: event.hasEnded ? 'Event ended' : event.isSoldOut ? 'Sold Out' : 'Select Tickets',
                  onPressed: canBook
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketSelectionScreen()))
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                if (actionLabel != null)
                  InkWell(
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(actionLabel!, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
