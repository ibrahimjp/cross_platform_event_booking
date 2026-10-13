import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../screens/event_details_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';

void openEvent(BuildContext context, Event event) {
  context.read<AppState>().setActiveEvent(event);
  Navigator.push(context, MaterialPageRoute(builder: (_) => const EventDetailsScreen()));
}

class WishlistButton extends StatelessWidget {
  const WishlistButton({super.key, required this.event, this.size = 20});

  final Event event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final saved = appState.isWishlisted(event.id);
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          try {
            await appState.toggleWishlist(event.id);
          } catch (error) {
            if (context.mounted) showMessage(context, errorText(error), error: true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? Colors.red : AppTheme.secondary, size: size),
        ),
      ),
    );
  }
}

/// Large vertical card used on Home.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  Positioned(top: 10, right: 10, child: WishlistButton(event: event)),
                  if (event.isSoldOut || event.hasEnded)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Badge(text: event.hasEnded ? 'ENDED' : 'SOLD OUT', color: Colors.red),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Badge(text: event.category, color: AppTheme.primary),
                        Text(
                          event.priceStarting == 0 ? 'Free' : 'From ${formatPrice(event.priceStarting)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppTheme.outline),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ),
                        Text(event.dateLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
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

/// Compact horizontal row used in Explore, Wishlist and search results.
class EventListTile extends StatelessWidget {
  const EventListTile({super.key, required this.event, this.trailing});

  final Event event;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openEvent(context, event),
          child: Row(
            children: [
              SizedBox(width: 110, height: 116, child: EventImage(event.imageUrl, iconSize: 28)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.category.toUpperCase(),
                              style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            event.isSoldOut ? 'Sold out' : formatPrice(event.priceStarting),
                            style: TextStyle(fontWeight: FontWeight.bold, color: event.isSoldOut ? Colors.red : null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppTheme.outline),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text('${event.venue.isNotEmpty ? '${event.venue} · ' : ''}${event.location}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(event.dateLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: color == Colors.red ? 0.9 : 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(color: color == Colors.red ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
