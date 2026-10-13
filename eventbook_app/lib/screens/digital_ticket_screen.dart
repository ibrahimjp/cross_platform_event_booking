import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DigitalTicketScreen extends StatelessWidget {
  final Booking booking;

  const DigitalTicketScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final event = booking.event;
    final holder = context.watch<AppState>().user?.name ?? '';
    const dark = AppTheme.onSurface;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Digital Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EventImage(event.imageUrl),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 16,
                          right: 16,
                          child: Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: DefaultTextStyle(
                      style: const TextStyle(color: dark),
                      child: Column(
                        children: [
                          if (booking.isCancelled)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Text('This booking was cancelled and is no longer valid.',
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          Row(children: [_info('TICKET HOLDER', holder), _info('BOOKING REF', booking.bookingRef)]),
                          const SizedBox(height: 16),
                          Row(children: [_info('DATE', event.dateLabel), _info('TIME', event.time)]),
                          const SizedBox(height: 16),
                          Row(children: [_info('VENUE', '${event.venue}\n${event.location}'), _info('STATUS', booking.testPayment ? '${booking.status} (Test)' : booking.status)]),
                          const SizedBox(height: 16),
                          Row(children: [_info('TICKETS', booking.ticketSummary), _info('PAID', formatPrice(booking.totalPaid))]),
                          const SizedBox(height: 24),
                          Row(
                            children: List.generate(
                              30,
                              (index) => Expanded(child: Container(height: 1.5, color: index.isEven ? Colors.grey.shade300 : Colors.transparent)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Opacity(
                            opacity: booking.isCancelled ? 0.25 : 1,
                            child: QrImageView(
                              data: booking.qrData,
                              size: 180,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.primary),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: dark),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Show this QR code at the venue entrance',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondary, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
        ],
      ),
    );
  }
}
