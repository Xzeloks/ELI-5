import 'package:flutter_riverpod/flutter_riverpod.dart';

// Enum for filter types
enum HistoryFilterType {
  all,
  text,
  image,
  link,
  starred,
}

// Provider for the current search term in the history list
final historySearchQueryProvider = StateProvider<String>((ref) => '');

// Provider for the currently selected filter in the history list
final historyFilterProvider = StateProvider<HistoryFilterType>((ref) => HistoryFilterType.all);

// Provider for the list of available filters (could be extended later)
// This is simple for now, but could fetch from a dynamic source if needed.
final historyAvailableFiltersProvider = Provider<List<HistoryFilterType>>((ref) {
  return HistoryFilterType.values;
});

// Provider to hold the ID of the session currently pending deletion (for optimistic UI updates)
final sessionPendingDeleteIdProvider = StateProvider<String?>((ref) => null);

// Provider to hold the list of currently selected session IDs for multi-select
final selectedSessionIdsProvider = StateProvider<List<String>>((ref) => []);

// Provider to indicate if multi-select mode is active in the history screen
final isHistoryMultiSelectActiveProvider = StateProvider<bool>((ref) => false);

// Provider to hold the list of session IDs currently pending BATCH deletion (for optimistic UI updates with Undo)
final batchSessionsPendingDeleteProvider = StateProvider<List<String>>((ref) => []); 