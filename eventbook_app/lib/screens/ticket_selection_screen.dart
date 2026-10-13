import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'payment_screen.dart';

class TicketSelectionScreen extends StatelessWidget {
  const TicketSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final event = appState.activeEvent;
    if (event == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy, message: 'Event not found.'));
    final totalCount = appState.totalTicketsSelected;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Tickets', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(context),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 70, height: 70, child: EventImage(event.imageUrl, iconSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${event.dateLabel} · ${event.time}', style: Theme.of(context).textTheme.bodySmall),
                      Text(event.venue, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Choose up to 10 per ticket type', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          ...event.ticketCategories.map((category) => _TicketTile(category: category, count: appState.selectedTickets[category.id] ?? 0)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: AppTheme.barColor(context),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total ($totalCount ${totalCount == 1 ? 'ticket' : 'tickets'})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(formatAmount(appState.ticketsSubtotal),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('+ 18% GST, calculated at checkout', style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: totalCount == 0 ? 'Select at least one ticket' : 'Proceed to Payment',
                onPressed: totalCount > 0
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.category, required this.count});

  final TicketCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final soldOut = category.remaining == 0;
    final atLimit = count >= (category.remaining < 10 ? category.remaining : 10);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        context,
        backgroundColor: count > 0 ? AppTheme.primary.withValues(alpha: 0.08) : null,
        borderColor: count > 0 ? AppTheme.primary : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (soldOut || category.remaining < 20)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(soldOut ? 'Sold out' : '${category.remaining} left',
                            style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                if (category.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(category.description, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                Text(formatPrice(category.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: AppTheme.subtle(context), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: count > 0 ? () => appState.updateTicketCount(category.id, -1) : null,
                ),
                Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: soldOut || atLimit ? null : () => appState.updateTicketCount(category.id, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
