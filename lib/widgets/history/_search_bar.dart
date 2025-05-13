// Placeholder for _SearchBar widget
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/providers/history_list_providers.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the current search query from the provider
    // This ensures that if the user navigates away and back, the search bar reflects the active query.
    _controller.text = ref.read(historySearchQueryProvider);
    _controller.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) { // Check if the widget is still in the tree
          ref.read(historySearchQueryProvider.notifier).state = _controller.text;
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Listen to the provider to update the text field if the query is changed externally
    // or cleared, etc. This creates a two-way binding.
    ref.listen<String>(historySearchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.text = next;
        // Move cursor to the end of the text
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      }
    });

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 8.0),
      child: TextField(
        controller: _controller,
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search history...',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: Icon(FeatherIcons.search, color: theme.colorScheme.onSurfaceVariant, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(FeatherIcons.x, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onPressed: () {
                    _controller.clear(); // This will trigger the listener and update the provider
                    // ref.read(historySearchQueryProvider.notifier).state = ''; // Also an option
                  },
                  tooltip: 'Clear search',
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest, // M3 search bar like color
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0), // Fully rounded
            borderSide: BorderSide.none, // No border for a cleaner M3 look
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
} 