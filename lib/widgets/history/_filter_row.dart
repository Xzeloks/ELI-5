// Placeholder for _FilterRow widget
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/providers/history_list_providers.dart';
import 'package:eli5/main.dart'; // Import AppColors

class FilterRowWidget extends ConsumerWidget {
  const FilterRowWidget({super.key});

  // Helper to get display text for filter types
  String _getFilterDisplayName(HistoryFilterType filterType) {
    switch (filterType) {
      case HistoryFilterType.all:
        return 'All';
      case HistoryFilterType.text:
        return 'Text';
      case HistoryFilterType.image:
        return 'Image';
      case HistoryFilterType.link:
        return 'Link';
      case HistoryFilterType.starred:
        return 'Starred';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final availableFilters = ref.watch(historyAvailableFiltersProvider);
    final selectedFilter = ref.watch(historyFilterProvider);

    return Material(
      elevation: 1.0, // Surface with elevation=1
      color: Theme.of(context).scaffoldBackgroundColor, // CHANGED: Match scaffold background
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), // Reduced horizontal to 8 for chips
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8.0, // Spacing between chips
            runSpacing: 8.0, // Spacing between lines of chips (if they wrap)
            children: availableFilters.map((filterType) {
              final bool isSelected = selectedFilter == filterType;
              return FilterChip(
                label: Text(_getFilterDisplayName(filterType)),
                selected: isSelected,
                onSelected: (bool selected) {
                  if (selected) {
                    ref.read(historyFilterProvider.notifier).state = filterType;
                  }
                },
                // Material 3 styling for FilterChip
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0), // M3 uses larger corner radius for chips
                  side: BorderSide(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                    width: 1.0,
                  ),
                ),
                backgroundColor: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.5) : theme.colorScheme.surfaceContainer, // M3 chip background
                selectedColor: theme.colorScheme.primaryContainer, // M3 selected chip background
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                ),
                checkmarkColor: isSelected ? theme.colorScheme.onPrimaryContainer : null,
                showCheckmark: false, // M3 often relies on background/border color change rather than checkmark for selection state
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Adjust padding as needed
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
} 