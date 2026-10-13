import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'activity_screen.dart';
import 'bookings_screen.dart';
import 'dashboard_screen.dart';
import 'events_screen.dart';
import 'promos_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

enum Section { dashboard, events, bookings, users, promos, activity, settings }

const _destinations = {
  Section.dashboard: (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Dashboard'),
  Section.events: (Icons.event_outlined, Icons.event, 'Events'),
  Section.bookings: (Icons.confirmation_number_outlined, Icons.confirmation_number, 'Bookings'),
  Section.users: (Icons.people_outline, Icons.people, 'Users'),
  Section.promos: (Icons.local_offer_outlined, Icons.local_offer, 'Promo codes'),
  Section.activity: (Icons.history_outlined, Icons.history, 'Activity log'),
  Section.settings: (Icons.tune_outlined, Icons.tune, 'Platform & settings'),
};

/// Lets any screen switch sections or open the navigation drawer on narrow layouts.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.select, required this.openMenu, required super.child});

  final void Function(Section section) select;
  final VoidCallback? openMenu;

  static ShellScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => openMenu != oldWidget.openMenu;
}

/// App bar used by every section; adds the drawer button on narrow layouts.
PreferredSizeWidget sectionAppBar(BuildContext context, String title, {List<Widget> actions = const []}) {
  final openMenu = ShellScope.of(context)?.openMenu;
  return AppBar(
    title: Text(title),
    leading: openMenu == null ? null : IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu), onPressed: openMenu),
    automaticallyImplyLeading: false,
    actions: [...actions, const SizedBox(width: 8)],
  );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Section _section = Section.dashboard;

  void _select(Section section) {
    setState(() => _section = section);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  Widget _page() => switch (_section) {
    Section.dashboard => const DashboardScreen(),
    Section.events => const EventsScreen(),
    Section.bookings => const BookingsScreen(),
    Section.users => const UsersScreen(),
    Section.promos => const PromosScreen(),
    Section.activity => const ActivityScreen(),
    Section.settings => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final page = KeyedSubtree(key: ValueKey(_section), child: _page());
    return ShellScope(
      select: _select,
      openMenu: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: wide
            ? null
            : Drawer(
                child: _NavList(selected: _section, onSelect: _select),
              ),
        body: wide
            ? Row(
                children: [
                  SizedBox(
                    width: width >= 1200 ? 250 : 220,
                    child: _NavList(selected: _section, onSelect: _select),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              )
            : page,
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.selected, required this.onSelect});

  final Section selected;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = SessionScope.of(context);
    final admin = session.admin;
    return Material(
      color: theme.navigationRailTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'EventBook Admin',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final entry in _destinations.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        dense: true,
                        selected: entry.key == selected,
                        selectedTileColor: theme.colorScheme.primaryContainer,
                        selectedColor: theme.colorScheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Icon(entry.key == selected ? entry.value.$2 : entry.value.$1),
                        title: Text(entry.value.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () => onSelect(entry.key),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            if (admin != null)
              ListTile(
                leading: UserAvatar(name: admin.name, url: admin.avatarUrl, radius: 16),
                title: Text(admin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(admin.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    if (await confirmAction(context, title: 'Sign out?', message: 'You will need to sign in again.')) {
                      await session.signOut();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
