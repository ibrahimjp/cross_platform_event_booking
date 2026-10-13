import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';
import 'home_screen.dart' show categoryIcons;

class AiForYouScreen extends StatelessWidget {
  const AiForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final events = appState.recommendedEvents;
    final preferences = appState.user?.preferredCategories ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('AI For You', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: appState.loadEvents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.glassDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: AppTheme.primary, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Taste Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Based on your preferences and city', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (preferences.isEmpty) const Chip(label: Text('No preferences yet — set them in Profile')),
                      ...preferences.map((category) => Chip(
                            avatar: Icon(categoryIcons[category] ?? Icons.label, size: 14, color: AppTheme.primary),
                            label: Text(category),
                          )),
                      if (appState.user?.city.isNotEmpty ?? false)
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 14, color: AppTheme.primary),
                          label: Text(appState.user!.city),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Personalized Top Matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (events.isEmpty)
              EmptyState(icon: Icons.auto_awesome, message: appState.eventLoadError ?? 'No events to recommend yet.')
            else
              ...events.map((event) => _MatchCard(event: event, match: appState.matchScore(event))),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.event, required this.match});

  final Event event;
  final int match;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openEvent(context, event),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(aspectRatio: 16 / 8, child: EventImage(event.imageUrl)),
                  Positioned(
                    top: 10,
                    left: 10,
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (event.aiReason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.aiReason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('${event.dateLabel} · ${event.location}', style: Theme.of(context).textTheme.bodySmall)),
                        Text(formatPrice(event.priceStarting), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
