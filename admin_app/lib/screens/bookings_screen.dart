import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'booking_detail.dart';
import 'shell.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const _filters = {
    '': 'All',
    'active': 'Active',
    'Confirmed': 'Paid',
    'Free': 'Free',
    'comp': 'Complimentary',
    'Cancelled': 'Cancelled',
    'refunded': 'Refunded',
  };

  Paged<Booking>? _page;
  Json? _summary;
  String? _error;
  String _query = '';
  String _status = '';
  int _pageNumber = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/bookings', {
        'q': _query,
        'status': _status,
        'page': _pageNumber,
      });
      if (!mounted) return;
      setState(() {
        _page = Paged.fromJson(data, 'bookings', Booking.fromJson);
        _summary = data['summary'] as Json?;
        _error = null;
      });
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
        'Bookings',
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
          if (await showCompTicketDialog(context)) _reload();
        },
        icon: const Icon(Icons.card_giftcard),
        label: const Text('Issue tickets'),
      ),
      body: PageBody(
        onRefresh: _load,
        children: [
          SearchField(
            hint: 'Search by customer, email, event, promo code, booking or payment ID',
            onSubmitted: (value) {
              _query = value;
              _reload();
            },
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
            if (_summary != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${count(page.total)} bookings · ${count(asInt(_summary!['tickets']))} tickets · '
                  '${money(asDouble(_summary!['revenue']))} active revenue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            if (page.items.isEmpty)
              const MessageView(icon: Icons.confirmation_number_outlined, message: 'No bookings match these filters.')
            else
              Card(
                child: Column(
                  children: [
                    for (final booking in page.items) ...[
                      BookingTile(
                        booking: booking,
                        onTap: () async {
                          if (await showBookingDetail(context, booking.id)) _load();
                        },
                      ),
                      if (booking != page.items.last) const Divider(),
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

class BookingTile extends StatelessWidget {
  const BookingTile({
    super.key,
    required this.booking,
    required this.onTap,
    this.showEvent = true,
    this.showUser = true,
  });

  final Booking booking;
  final VoidCallback onTap;
  final bool showEvent;
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = showEvent ? booking.eventTitle : booking.userName;
    final details = [
      if (showEvent && showUser) booking.userName,
      if (!showEvent && booking.userEmail.isNotEmpty) booking.userEmail,
      '${booking.ticketCount} ticket${booking.ticketCount == 1 ? '' : 's'}',
      dateTime(booking.createdAt),
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: showEvent
          ? EventThumb(url: booking.eventImage, size: 42)
          : UserAvatar(name: booking.userName, url: booking.userAvatar),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(booking.totalPaid), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          bookingStatusChip(booking),
        ],
      ),
    );
  }
}

/// Issues complimentary tickets. [user] and [event] preselect the recipient or event.
Future<bool> showCompTicketDialog(BuildContext context, {AdminUser? user, AdminEvent? event}) async {
  final issued = await showDialog<bool>(
    context: context,
    builder: (context) => _CompDialog(user: user, event: event),
  );
  return issued == true;
}

class _CompDialog extends StatefulWidget {
  const _CompDialog({this.user, this.event});

  final AdminUser? user;
  final AdminEvent? event;

  @override
  State<_CompDialog> createState() => _CompDialogState();
}

class _CompDialogState extends State<_CompDialog> {
  late AdminUser? _user = widget.user;
  late AdminEvent? _event = widget.event;
  final Map<String, int> _quantities = {};
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _total => _quantities.values.fold(0, (sum, value) => sum + value);

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => AdminApi.instance.post('/api/admin/bookings', {
        'userId': _user!.id,
        'eventId': _event!.id,
        'quantities': {
          for (final entry in _quantities.entries)
            if (entry.value > 0) entry.key: entry.value,
        },
        'note': _note.text.trim(),
      }),
      success: 'Issued $_total complimentary ticket(s) to ${_user!.name}.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return AlertDialog(
      title: const Text('Issue complimentary tickets'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Free tickets are taken from real inventory and appear in the customer\'s bookings.'),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _user == null
                    ? const CircleAvatar(child: Icon(Icons.person_add_alt))
                    : UserAvatar(name: _user!.name, url: _user!.avatarUrl),
                title: Text(_user?.name ?? 'Choose recipient'),
                subtitle: Text(_user?.email ?? 'Any customer account'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final picked = await pickUser(context, title: 'Recipient');
                  if (picked != null) setState(() => _user = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: event == null
                    ? const CircleAvatar(child: Icon(Icons.event))
                    : EventThumb(url: event.imageUrl, size: 40),
                title: Text(event?.title ?? 'Choose event'),
                subtitle: Text(event == null ? 'Upcoming events' : dateTime(event.startsAt)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final picked = await pickEvent(context);
                  if (picked != null) {
                    setState(() {
                      _event = picked;
                      _quantities.clear();
                    });
                  }
                },
              ),
              if (event != null) ...[
                const Divider(height: 24),
                for (final ticket in event.ticketCategories)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ticket.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${money(ticket.price)} · ${ticket.remaining} left',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fewer',
                        onPressed: (_quantities[ticket.id] ?? 0) > 0
                            ? () => setState(() => _quantities[ticket.id] = _quantities[ticket.id]! - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(width: 28, child: Text('${_quantities[ticket.id] ?? 0}', textAlign: TextAlign.center)),
                      IconButton(
                        tooltip: 'More',
                        onPressed:
                            (_quantities[ticket.id] ?? 0) < ticket.remaining && (_quantities[ticket.id] ?? 0) < 50
                            ? () => setState(() => _quantities[ticket.id] = (_quantities[ticket.id] ?? 0) + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Internal note (e.g. press, sponsor)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy || _user == null || event == null || _total == 0 ? null : _submit,
          child: Text(_total == 0 ? 'Issue tickets' : 'Issue $_total ticket${_total == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
}
