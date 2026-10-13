import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'digital_ticket_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  final Booking booking;

  const BookingSuccessScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 64),
                  ),
                  const SizedBox(height: 20),
                  const Text('Booking Confirmed!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Booking ID: ${booking.bookingRef}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration(context),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(width: 64, height: 64, child: EventImage(booking.event.imageUrl, iconSize: 22)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking.event.title,
                                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('${booking.event.dateLabel} · ${booking.event.venue}',
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _row(context, 'Tickets', booking.ticketSummary),
                        const SizedBox(height: 8),
                        _row(context, booking.totalPaid == 0 ? 'Amount' : booking.testPayment ? 'Total (test payment)' : 'Total Paid', formatPrice(booking.totalPaid), highlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    label: 'View Digital Ticket',
                    icon: Icons.qr_code,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DigitalTicketScreen(booking: booking))),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      context.read<AppState>().setNavIndex(3);
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('Go to My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.outline)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, color: highlight ? AppTheme.primary : null, fontSize: highlight ? 16 : 14),
          ),
        ),
      ],
    );
  }
}
