import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'booking_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _promoController = TextEditingController();
  bool _isPaying = false;
  bool _isTestPaying = false;
  bool _applyingPromo = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo(AppState appState) async {
    FocusScope.of(context).unfocus();
    setState(() => _applyingPromo = true);
    try {
      final discount = await appState.applyPromoCode(_promoController.text);
      if (mounted) showMessage(context, 'Promo applied! You save ${formatAmount(discount)}.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  Future<void> _pay(AppState appState) async {
    setState(() => _isPaying = true);
    try {
      final start = await appState.startCheckout();
      if (!mounted) return;
      Booking? booking = start.booking;
      if (booking == null) {
        final opened = await openExternalUrl(start.url!);
        if (!mounted) return;
        if (!opened) {
          showMessage(context, 'Could not open the Stripe payment page.', error: true);
          return;
        }
        final status = await showDialog<CheckoutStatus>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _AwaitPaymentDialog(sessionId: start.sessionId!, url: start.url!),
        );
        if (!mounted || status == null) return;
        if (status.status != 'paid' || status.booking == null) {
          showMessage(
            context,
            status.message ??
                (status.status == 'expired' ? 'The payment session expired. Please try again.' : 'Payment was not completed.'),
            error: true,
          );
          return;
        }
        booking = status.booking;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking!)),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _testPay(AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Test payment'),
        content: Text(
          'This is a demo payment. Your ticket will be booked for ${formatAmount(appState.grandTotal)} without charging any card, '
          'and the booking will be marked as a test.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm test payment')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isTestPaying = true);
    try {
      final booking = await appState.testCheckout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking)),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _isTestPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final event = appState.activeEvent;
    if (event == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy, message: 'Event not found.'));
    final subtotal = appState.ticketsSubtotal;
    final discount = appState.discountAmount;
    final total = appState.grandTotal;
    final selected = event.ticketCategories.where((c) => (appState.selectedTickets[c.id] ?? 0) > 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Booking Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(width: 60, height: 60, child: EventImage(event.imageUrl, iconSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('${event.dateLabel} · ${event.venue}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ...selected.map((category) {
                  final qty = appState.selectedTickets[category.id]!;
                  return _row('$qty × ${category.name}', formatAmount(category.price * qty));
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Promo Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (appState.appliedPromoCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${appState.appliedPromoCode} applied · -${formatAmount(discount)}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(onPressed: appState.removePromoCode, child: const Text('Remove')),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Try EVEAI200',
                      filled: true,
                      fillColor: AppTheme.subtle(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _applyPromo(appState),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyingPromo || subtotal == 0 ? null : () => _applyPromo(appState),
                  child: Text(_applyingPromo ? '…' : 'Apply'),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              children: [
                _row('Ticket Subtotal', formatAmount(subtotal)),
                if (discount > 0) _row('Promo Discount', '-${formatAmount(discount)}', color: Colors.green),
                _row('GST & Taxes (18%)', formatAmount(appState.taxes)),
                const Divider(height: 20),
                _row('Total Payable', formatAmount(total), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    total == 0
                        ? 'This is a free booking. Your ticket is issued instantly.'
                        : 'Secure checkout powered by Stripe opens in your browser. Test card: 4242 4242 4242 4242, any future date, any CVC.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        color: AppTheme.barColor(context),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientButton(
                loading: _isPaying,
                icon: total == 0 ? Icons.check_circle_outline : Icons.lock,
                label: total == 0 ? 'Confirm Free Booking' : 'Pay ${formatAmount(total)}',
                onPressed: appState.totalTicketsSelected == 0 || _isTestPaying ? null : () => _pay(appState),
              ),
              if (total > 0 && appState.testPaymentsEnabled) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isTestPaying
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.science_outlined, color: AppTheme.primary),
                  label: const Text('Test Payment (demo, no charge)',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  onPressed: appState.totalTicketsSelected == 0 || _isPaying || _isTestPaying ? null : () => _testPay(appState),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String amount, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
          ),
          Text(amount,
              style: TextStyle(
                fontSize: bold ? 18 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color ?? (bold ? AppTheme.primary : null),
              )),
        ],
      ),
    );
  }
}

/// Polls the backend until Stripe reports the checkout as paid, expired or refunded.
class _AwaitPaymentDialog extends StatefulWidget {
  const _AwaitPaymentDialog({required this.sessionId, required this.url});

  final String sessionId;
  final String url;

  @override
  State<_AwaitPaymentDialog> createState() => _AwaitPaymentDialogState();
}

class _AwaitPaymentDialogState extends State<_AwaitPaymentDialog> with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final status = await context.read<AppState>().checkCheckout(widget.sessionId);
      if (!mounted) return;
      if (status.isFinal) {
        _timer?.cancel();
        Navigator.pop(context, status);
      } else if (_error != null) {
        setState(() => _error = null);
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete your payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Finish paying on the Stripe page that opened in your browser. This screen updates automatically once the payment succeeds.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => openExternalUrl(widget.url), child: const Text('Reopen page')),
        FilledButton(onPressed: _check, child: const Text('I\'ve paid')),
      ],
    );
  }
}
