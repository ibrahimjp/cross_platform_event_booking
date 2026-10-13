import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ai_assistant_screen.dart';
import 'ai_for_you_screen.dart';
import 'event_form_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'hosted_events_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key});

  static const _pages = [
    HomeScreen(),
    ExploreScreen(),
    AiForYouScreen(),
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      drawer: _AppDrawer(appState: appState),
      body: IndexedStack(index: appState.navIndex, children: _pages),
      floatingActionButton: appState.navIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'host-event',
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Host Event'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventFormScreen())),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: appState.navIndex,
        onDestinationSelected: appState.setNavIndex,
        indicatorColor: AppTheme.primaryContainer.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppTheme.primary), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: AppTheme.primary), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome, color: AppTheme.primary), label: 'For You'),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number, color: AppTheme.primary),
            label: 'Bookings',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppTheme.primary), label: 'Profile'),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.appState});

  final AppState appState;

  void _go(BuildContext context, int index) {
    Navigator.pop(context);
    appState.setNavIndex(index);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: UserAvatar(name: user?.name ?? '', url: user?.avatarUrl ?? '', radius: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'EventBook',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.home_outlined, color: AppTheme.primary), title: const Text('Home'), onTap: () => _go(context, 0)),
          ListTile(leading: const Icon(Icons.explore_outlined, color: AppTheme.primary), title: const Text('Explore Events'), onTap: () => _go(context, 1)),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
            title: const Text('Host an Event'),
            onTap: () => _push(context, const EventFormScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined, color: AppTheme.primary),
            title: const Text('My Hosted Events'),
            onTap: () => _push(context, const HostedEventsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined, color: AppTheme.primary),
            title: const Text('EventAI Assistant'),
            onTap: () => _push(context, const AiAssistantScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline, color: AppTheme.primary),
            title: const Text('Wishlist'),
            trailing: Text('${appState.wishlistEvents.length}'),
            onTap: () => _push(context, const WishlistScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primary),
            title: const Text('My Bookings'),
            onTap: () => _go(context, 3),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Profile & Settings'),
            onTap: () => _go(context, 4),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              appState.logout();
            },
          ),
        ],
      ),
    );
  }
}
