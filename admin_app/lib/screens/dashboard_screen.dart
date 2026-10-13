import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'booking_detail.dart';
import 'event_detail_screen.dart';
import 'shell.dart';
import 'user_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Json? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/overview');
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/settings', {key: value}),
      success: 'Platform setting updated.',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar(
        context,
        'Dashboard',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _data == null
          ? (_error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load))
          : _buildBody(context, _data!),
    );
  }

  Widget _buildBody(BuildContext context, Json data) {
    final totals = data['totals'] as Json;
    final settings = PlatformSettings.fromJson(data['settings'] as Json?);
    final shell = ShellScope.of(context);
    final daily = (data['daily'] as List).cast<Json>();
    final categories = (data['categories'] as List).cast<Json>();
    final topEvents = (data['topEvents'] as List).cast<Json>();
    final lowInventory = (data['lowInventory'] as List).cast<Json>();
    final recentBookings = (data['recentBookings'] as List).map((b) => Booking.fromJson(b as Json)).toList();
    final recentUsers = (data['recentUsers'] as List).map((u) => AdminUser.fromJson(u as Json)).toList();

    return PageBody(
      onRefresh: _load,
      children: [
        if (settings.salesPaused || !settings.registrationsOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MaterialBanner(
              backgroundColor: Tone.warning.withValues(alpha: 0.12),
              leading: const Icon(Icons.warning_amber_rounded, color: Tone.warning),
              content: Text(
                [
                  if (settings.salesPaused) 'Ticket sales are paused for all customers.',
                  if (!settings.registrationsOpen) 'New sign-ups are closed.',
                ].join(' '),
              ),
              actions: [TextButton(onPressed: () => shell?.select(Section.settings), child: const Text('Manage'))],
            ),
          ),
        ResponsiveGrid(
          minItemWidth: 180,
          children: [
            KpiCard(
              label: 'Gross revenue',
              value: moneyCompact(asDouble(totals['revenue'])),
              icon: Icons.payments_outlined,
              color: Tone.success,
              caption: '${moneyCompact(asDouble(totals['revenue30d']))} in last 30 days',
              onTap: () => shell?.select(Section.bookings),
            ),
            KpiCard(
              label: 'Tickets sold',
              value: count(asInt(totals['ticketsSold'])),
              icon: Icons.confirmation_number_outlined,
              caption: '${count(asInt(totals['activeBookings']))} active bookings',
              onTap: () => shell?.select(Section.bookings),
            ),
            KpiCard(
              label: 'Events',
              value: count(asInt(totals['events'])),
              icon: Icons.event_outlined,
              color: Tone.info,
              caption: '${totals['upcomingEvents']} upcoming · ${totals['hiddenEvents']} hidden',
              onTap: () => shell?.select(Section.events),
            ),
            KpiCard(
              label: 'Users',
              value: count(asInt(totals['users'])),
              icon: Icons.people_outline,
              color: const Color(0xFF0891B2),
              caption: '+${totals['newUsers30d']} in 30 days · ${totals['blockedUsers']} suspended',
              onTap: () => shell?.select(Section.users),
            ),
            KpiCard(
              label: 'Cancelled',
              value: count(asInt(totals['cancelledBookings'])),
              icon: Icons.event_busy_outlined,
              color: Tone.danger,
              caption: '${moneyCompact(asDouble(totals['refunded']))} refunded',
            ),
            KpiCard(
              label: 'Admins',
              value: count(asInt(totals['admins'])),
              icon: Icons.shield_outlined,
              color: Tone.warning,
              caption: 'with full platform access',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TwoColumn(
          left: SectionCard(
            title: 'Last 30 days',
            child: _RevenueChart(daily: daily),
          ),
          right: SectionCard(
            title: 'Platform switches',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ticket sales'),
                  subtitle: Text(settings.salesPaused ? 'Paused: checkout is blocked' : 'Live: customers can buy'),
                  value: !settings.salesPaused,
                  onChanged: (value) => _toggle('salesPaused', !value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New sign-ups'),
                  subtitle: Text(settings.registrationsOpen ? 'Open' : 'Closed'),
                  value: settings.registrationsOpen,
                  onChanged: (value) => _toggle('registrationsOpen', value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TwoColumn(
          left: SectionCard(
            title: 'Top events by revenue',
            child: topEvents.isEmpty
                ? const _Empty('No sales yet.')
                : Column(
                    children: [
                      for (final event in topEvents)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: EventThumb(url: event['imageUrl'] as String? ?? '', size: 40),
                          title: Text(event['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${count(asInt(event['tickets']))} tickets'),
                          trailing: Text(
                            money(asDouble(event['revenue'])),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () => openEvent(context, event['id'] as String, onChanged: _load),
                        ),
                    ],
                  ),
          ),
          right: SectionCard(
            title: 'Revenue by category',
            child: categories.isEmpty ? const _Empty('No sales yet.') : _CategoryBars(categories: categories),
          ),
        ),
        const SizedBox(height: 16),
        if (lowInventory.isNotEmpty) ...[
          SectionCard(
            title: 'Running low on tickets',
            trailing: const Icon(Icons.inventory_2_outlined, color: Tone.warning),
            child: Column(
              children: [
                for (final event in lowInventory)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(event['title'] as String),
                    subtitle: Text(
                      [
                        dateShort(asDate(event['startsAt'])),
                        for (final ticket in (event['tickets'] as List).cast<Json>())
                          '${ticket['name']}: ${ticket['remaining']} left',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openEvent(context, event['id'] as String, onChanged: _load),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _TwoColumn(
          left: SectionCard(
            title: 'Latest bookings',
            trailing: TextButton(onPressed: () => shell?.select(Section.bookings), child: const Text('View all')),
            child: recentBookings.isEmpty
                ? const _Empty('No bookings yet.')
                : Column(
                    children: [
                      for (final booking in recentBookings)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(name: booking.userName, url: booking.userAvatar),
                          title: Text(booking.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${booking.userName} · ${timeAgo(booking.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(money(booking.totalPaid), style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              bookingStatusChip(booking),
                            ],
                          ),
                          onTap: () async {
                            if (await showBookingDetail(context, booking.id)) _load();
                          },
                        ),
                    ],
                  ),
          ),
          right: SectionCard(
            title: 'New users',
            trailing: TextButton(onPressed: () => shell?.select(Section.users), child: const Text('View all')),
            child: Column(
              children: [
                for (final user in recentUsers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(name: user.name, url: user.avatarUrl),
                    title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(timeAgo(user.createdAt), style: Theme.of(context).textTheme.bodySmall),
                    onTap: () => openUser(context, user.id, onChanged: _load),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
  );
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: right),
            ],
          ),
        );
      },
    );
  }
}

class _RevenueChart extends StatefulWidget {
  const _RevenueChart({required this.daily});

  final List<Json> daily;

  @override
  State<_RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<_RevenueChart> {
  bool _showRevenue = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      for (final day in widget.daily) _showRevenue ? asDouble(day['revenue']) : asDouble(day['bookings']),
    ];
    final peak = values.fold<double>(0, (max, value) => value > max ? value : max);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _showRevenue ? money(total) : '${count(total)} bookings',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Revenue')),
                ButtonSegment(value: false, label: Text('Bookings')),
              ],
              selected: {_showRevenue},
              onSelectionChanged: (value) => setState(() => _showRevenue = value.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${dayMonth(DateTime.parse(widget.daily[i]['date'] as String))}: '
                        '${_showRevenue ? money(values[i]) : '${values[i].toInt()} bookings'}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Container(
                        height: peak == 0 ? 2 : (values[i] / peak * 160).clamp(2, 160),
                        decoration: BoxDecoration(
                          color: values[i] == 0 ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5) : brand,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final index in [0, 10, 20, 29])
              Text(dayMonth(DateTime.parse(widget.daily[index]['date'] as String)), style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.categories});

  final List<Json> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = categories.fold<double>(
      0,
      (max, row) => asDouble(row['revenue']) > max ? asDouble(row['revenue']) : max,
    );
    return Column(
      children: [
        for (final row in categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['category'] as String? ?? 'Other',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${money(asDouble(row['revenue']))} · ${row['tickets']} tickets',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: peak == 0 ? 0 : asDouble(row['revenue']) / peak,
                    backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
