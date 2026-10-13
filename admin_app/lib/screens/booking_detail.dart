import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'event_detail_screen.dart';
import 'user_detail_screen.dart';

/// Opens the booking inspector. Resolves to true when the booking was changed.
Future<bool> showBookingDetail(BuildContext context, String bookingId) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (context) => _BookingDialog(bookingId: bookingId),
  );
  return changed == true;
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({required this.bookingId});

  final String bookingId;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  Booking? _booking;
  Json? _payment;
  String? _error;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/bookings/${widget.bookingId}');
      if (!mounted) return;
      setState(() {
        _booking = Booking.fromJson(data['booking'] as Json);
        _payment = data['payment'] as Json?;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _cancel() async {
    final booking = _booking!;
    final paid = booking.totalPaid > 0 && booking.paymentIntentId.isNotEmpty;
    final result = await showDialog<(bool, String)>(
      context: context,
      builder: (context) => _CancelDialog(booking: booking, paid: paid),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => AdminApi.instance.post('/api/admin/bookings/${booking.id}/cancel', {
        'refund': result.$1,
        'reason': result.$2,
      }),
      success: result.$1 && paid ? 'Booking cancelled and refunded.' : 'Booking cancelled.',
    );
    if (ok) _changed = true;
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  Future<void> _editNote() async {
    final note = await promptText(
      context,
      title: 'Admin note',
      label: 'Visible only to admins',
      initial: _booking!.adminNote,
      maxLines: 4,
    );
    if (note == null || !mounted) return;
    final ok = await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/bookings/${_booking!.id}', {'adminNote': note}),
      success: 'Note saved.',
    );
    if (ok) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete booking record?',
      message:
          'This permanently removes the cancelled booking from the database. Financial history for it will be lost.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runAction(
      context,
      () => AdminApi.instance.delete('/api/admin/bookings/${_booking!.id}'),
      success: 'Booking record deleted.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: booking == null
            ? SizedBox(
                height: 240,
                child: _error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking #${booking.shortId}',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              bookingStatusChip(booking),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy booking ID',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: booking.id));
                            toast(context, 'Booking ID copied.');
                          },
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context, _changed),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(20),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: EventThumb(url: booking.eventImage, size: 44),
                          title: Text(booking.eventTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(dateTime(booking.eventStartsAt)),
                          trailing: booking.eventTitle == 'Deleted event'
                              ? null
                              : const Icon(Icons.open_in_new, size: 18),
                          onTap: booking.eventTitle == 'Deleted event'
                              ? null
                              : () => openEvent(context, booking.eventId),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(name: booking.userName, url: booking.userAvatar),
                          title: Text(booking.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(booking.userEmail),
                          trailing: booking.userEmail.isEmpty ? null : const Icon(Icons.open_in_new, size: 18),
                          onTap: booking.userEmail.isEmpty ? null : () => openUser(context, booking.userId),
                        ),
                        const SizedBox(height: 8),
                        Text('Tickets', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        for (final line in booking.lines)
                          InfoRow('${line.quantity} × ${line.name}', money(line.price * line.quantity)),
                        const Divider(height: 20),
                        InfoRow('Subtotal', money(booking.subtotal)),
                        InfoRow(
                          booking.issuedByAdmin ? 'Complimentary' : 'Discount',
                          '− ${money(booking.discount)}${booking.promoCode.isEmpty ? '' : ' (${booking.promoCode})'}',
                        ),
                        InfoRow('GST & fees', money(booking.taxesAndFees)),
                        InfoRow('Total paid', money(booking.totalPaid), bold: true),
                        const Divider(height: 20),
                        InfoRow('Booked on', dateTime(booking.createdAt)),
                        if (booking.paymentIntentId.isNotEmpty) InfoRow('Payment intent', booking.paymentIntentId),
                        if (_payment != null) ..._paymentRows(_payment!),
                        if (booking.isCancelled) ...[
                          InfoRow(
                            'Cancelled',
                            '${dateTime(booking.cancelledAt)} by ${booking.cancelledBy ?? 'unknown'}',
                          ),
                          if (booking.cancelReason.isNotEmpty) InfoRow('Reason', booking.cancelReason),
                          InfoRow('Refunded', booking.refunded ? 'Yes' : 'No'),
                        ],
                        InfoRow('Admin note', booking.adminNote),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _busy ? null : _editNote,
                          icon: const Icon(Icons.sticky_note_2_outlined),
                          label: const Text('Note'),
                        ),
                        if (booking.isCancelled)
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Tone.danger),
                            onPressed: _busy ? null : _delete,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete record'),
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Tone.danger),
                            onPressed: _busy ? null : _cancel,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel booking'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _paymentRows(Json payment) {
    if (payment['error'] != null) return [InfoRow('Stripe', 'Could not load: ${payment['error']}')];
    final card = (payment['cardBrand'] as String? ?? '').isEmpty
        ? ''
        : '${(payment['cardBrand'] as String).toUpperCase()} •••• ${payment['cardLast4']}';
    return [
      InfoRow('Stripe status', '${payment['status']}${payment['livemode'] == true ? ' (live)' : ' (test)'}'),
      if (card.isNotEmpty) InfoRow('Card', card),
      if (asDouble(payment['amountRefunded']) > 0)
        InfoRow('Stripe refunded', money(asDouble(payment['amountRefunded']))),
      if ((payment['receiptUrl'] as String? ?? '').isNotEmpty) InfoRow('Receipt', payment['receiptUrl'] as String),
    ];
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.booking, required this.paid});

  final Booking booking;
  final bool paid;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();
  bool _refund = true;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel booking?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.booking.ticketCount} ticket(s) for "${widget.booking.eventTitle}" go back on sale.'),
            if (widget.paid)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _refund,
                onChanged: (value) => setState(() => _refund = value ?? true),
                title: Text('Refund ${money(widget.booking.totalPaid)} through Stripe'),
                subtitle: const Text('Turn off only if you refunded the customer another way.'),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep booking')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tone.danger),
          onPressed: () => Navigator.pop(context, (_refund, _reason.text.trim())),
          child: const Text('Cancel booking'),
        ),
      ],
    );
  }
}
