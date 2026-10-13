import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';
import 'ai_assistant_screen.dart';
import 'ticket_selection_screen.dart';

const categoryIcons = {
  'Music': Icons.music_note,
  'Festival': Icons.festival,
  'Networking': Icons.groups,
  'Food': Icons.restaurant,
  'Cultural': Icons.museum,
  'Sports': Icons.sports_cricket,
  'Comedy': Icons.theater_comedy,
  'Workshop': Icons.build,
};

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final events = appState.events;
    final recommended = appState.recommendedEvents;
    final heroEvent = recommended.isEmpty ? null : recommended.first;
    final garbaEvents = events.where((e) => e.isGarbaSpecial || e.category == 'Festival').toList();
    final trendingEvents = events.where((e) => !garbaEvents.contains(e) && e.id != heroEvent?.id).toList()
      ..sort((a, b) => b.goingCount.compareTo(a.goingCount));
    final firstName = appState.user?.name.split(' ').first ?? '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: appState.loadEvents,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.menu, size: 26), onPressed: () => Scaffold.of(context).openDrawer()),
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          'EventBook',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        tooltip: 'EventAI Assistant',
                        icon: const Icon(Icons.smart_toy_outlined, color: AppTheme.primary, size: 28),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
                      ),
                    ],
                  ),
                ),
              ),
              if (firstName.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Hi $firstName 👋  Discover what\'s happening near you', style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              if (appState.eventLoadError != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(child: Text(appState.eventLoadError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                        TextButton(onPressed: appState.loadEvents, child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
              if (!appState.eventsLoaded && appState.eventsLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.event_busy,
                    message: appState.eventLoadError == null ? 'No upcoming events yet. Be the first to host one!' : 'Events could not be loaded.',
                  ),
                )
              else ...[
                if (heroEvent != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
                              const SizedBox(width: 8),
                              Text('AI Recommendations for You',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _HeroCard(event: heroEvent, match: appState.matchScore(heroEvent)),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Explore Categories',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: categoryIcons.entries.map((entry) {
                              final count = events.where((e) => e.category == entry.key).length;
                              return _CategoryCard(
                                title: entry.key,
                                icon: entry.value,
                                count: count,
                                onTap: () => appState.exploreCategory(entry.key),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (garbaEvents.isNotEmpty) ...[
                  _SectionHeader(title: 'Upcoming Garba & Festivals', onViewAll: () => appState.exploreCategory('Festival')),
                  _EventList(events: garbaEvents.take(4).toList()),
                ],
                if (trendingEvents.isNotEmpty) ...[
                  _SectionHeader(title: 'Trending Now', onViewAll: () => appState.exploreCategory('All')),
                  _EventList(events: trendingEvents.take(6).toList()),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18))),
            TextButton(onPressed: onViewAll, child: const Text('View All', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) => EventCard(event: events[index]),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.event, required this.match});

  final Event event;
  final int match;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, borderRadius: 20, borderColor: AppTheme.primaryContainer.withValues(alpha: 0.25)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: EventImage(event.imageUrl)),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 4),
                      Text('$match% Match', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Positioned(top: 10, right: 10, child: WishlistButton(event: event)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(event.category.toUpperCase(),
                          style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today, size: 14, color: AppTheme.outline),
                    const SizedBox(width: 4),
                    Expanded(child: Text(event.dateLabel, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        label: event.isSoldOut ? 'Sold Out' : 'Book Now',
                        icon: Icons.arrow_forward,
                        onPressed: event.isSoldOut
                            ? null
                            : () {
                                context.read<AppState>().setActiveEvent(event);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketSelectionScreen()));
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => openEvent(context, event),
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.title, required this.icon, required this.count, required this.onTap});

  final String title;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: AppTheme.isDark(context) ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.primary, size: 28),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('$count event${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, color: AppTheme.outline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
