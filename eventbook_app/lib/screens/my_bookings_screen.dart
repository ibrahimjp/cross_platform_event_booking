import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'digital_ticket_screen.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: appState.loadUserBookings),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            tabs: [
              Tab(text: 'Upcoming (${appState.upcomingBookings.length})'),
              Tab(text: 'Past (${appState.pastBookings.length})'),
              Tab(text: 'Cancelled (${appState.cancelledBookings.length})'),
            ],
          ),
        ),
        body: appState.bookingsLoading && appState.userBookings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _BookingList(bookings: appState.upcomingBookings, empty: 'No upcoming bookings yet. Explore events and book your first ticket!'),
                  _BookingList(bookings: appState.pastBookings, empty: 'No past events yet.'),
                  _BookingList(bookings: appState.cancelledBookings, empty: 'No cancelled bookings.'),
                ],
              ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({required this.bookings, required this.empty});

  final List<Booking> bookings;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final error = context.select<AppState, String?>((state) => state.bookingLoadError);
    return RefreshIndicator(
      onRefresh: appState.loadUserBookings,
      child: bookings.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [const SizedBox(height: 80), EmptyState(icon: Icons.confirmation_number_outlined, message: error ?? empty)],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: bookings.length,
              itemBuilder: (context, index) => _BookingCard(booking: bookings[index]),
            ),
    );
  }
}

class _BookingCard extends StatefulWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final booking = widget.booking;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(booking.totalPaid > 0 && !booking.testPayment
            ? 'Your ${formatAmount(booking.totalPaid)} payment will be refunded to the original card via Stripe.'
            : 'Your ticket will be released for someone else.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep booking')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await context.read<AppState>().cancelBooking(booking.id);
      if (mounted) showMessage(context, booking.totalPaid > 0 && !booking.testPayment ? 'Booking cancelled and refund issued.' : 'Booking cancelled.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final statusColor = booking.isCancelled ? Colors.red : (booking.isPast ? AppTheme.outline : Colors.green);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 70, height: 70, child: EventImage(booking.event.imageUrl, iconSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(booking.isPast ? 'ATTENDED' : booking.status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        if (booking.testPayment)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text('TEST', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        Text(booking.bookingRef, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.outline)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(booking.event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('${booking.event.dateLabel} · ${booking.event.time}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(booking.ticketSummary, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Booked ${DateFormat('MMM d, y · h:mm a').format(booking.bookingDate)} · ${formatPrice(booking.totalPaid)}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (booking.isUpcoming)
                TextButton(
                  onPressed: _cancelling ? null : _cancel,
                  child: Text(_cancelling ? 'Cancelling…' : 'Cancel', style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('View Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DigitalTicketScreen(booking: booking))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
