import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final events = appState.filteredEvents;
    if (_searchController.text != appState.searchQuery) {
      _searchController.value = TextEditingValue(
        text: appState.searchQuery,
        selection: TextSelection.collapsed(offset: appState.searchQuery.length),
      );
    }
    final cityHint = appState.user?.city.isNotEmpty == true ? appState.user!.city : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Events', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<EventSort>(
            tooltip: 'Sort events',
            icon: const Icon(Icons.sort),
            initialValue: appState.sort,
            onSelected: appState.setSort,
            itemBuilder: (_) => EventSort.values
                .map((sort) => CheckedPopupMenuItem(value: sort, checked: sort == appState.sort, child: Text(sort.label)))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: TextField(
              controller: _searchController,
              onChanged: appState.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search events, venues, cities, artists…',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: appState.searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => appState.setSearchQuery(''))
                    : null,
                filled: true,
                fillColor: AppTheme.subtle(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                for (final filter in dateFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter == 'Near Me' && cityHint != null ? 'Near Me ($cityHint)' : filter),
                      selected: appState.selectedDateFilter == filter,
                      selectedColor: AppTheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: appState.selectedDateFilter == filter ? Colors.white : null,
                        fontWeight: appState.selectedDateFilter == filter ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        if (filter == 'Near Me' && cityHint == null) {
                          showMessage(context, 'Set your city in Profile → Personal Information to use Near Me.');
                        }
                        appState.setDateFilter(filter);
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Free only'),
                    selected: appState.freeOnly,
                    onSelected: appState.setFreeOnly,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: ['All', ...appState.categories].map((category) {
                final selected = appState.selectedCategoryFilter == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => appState.setCategoryFilter(category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : AppTheme.subtle(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: selected ? Colors.white : null,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${events.length} event${events.length == 1 ? '' : 's'} · ${appState.sort.label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (appState.hasActiveFilters)
                  TextButton.icon(
                    onPressed: appState.clearFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: appState.loadEvents,
              child: events.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.search_off,
                          message: appState.eventLoadError ?? 'No events match these filters.',
                          action: appState.hasActiveFilters
                              ? OutlinedButton(onPressed: appState.clearFilters, child: const Text('Clear filters'))
                              : null,
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: events.length,
                      itemBuilder: (context, index) => EventListTile(event: events[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
