import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final wishlist = appState.wishlistEvents;

    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist', style: TextStyle(fontWeight: FontWeight.bold))),
      body: wishlist.isEmpty
          ? const EmptyState(icon: Icons.favorite_border, message: 'Your wishlist is empty.\nTap the heart on any event to save it here.')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: wishlist.length,
              itemBuilder: (context, index) {
                final event = wishlist[index];
                return EventListTile(
                  event: event,
                  trailing: IconButton(
                    tooltip: 'Remove from wishlist',
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      try {
                        await appState.toggleWishlist(event.id);
                      } catch (error) {
                        if (context.mounted) showMessage(context, errorText(error), error: true);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
