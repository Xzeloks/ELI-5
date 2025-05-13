import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/screens/chat_screen.dart';
import 'package:eli5/screens/settings_screen.dart';
import 'package:eli5/screens/history_list_screen.dart';
import 'package:eli5/providers/chat_provider.dart';
import 'package:eli5/main.dart'; // ADDED import for AppColors
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
import 'package:curved_navigation_bar/curved_navigation_bar.dart'; // Import curved_navigation_bar
import 'dart:ui'; // Import for ImageFilter

// Provider for managing AppShell's selected index
final appShellSelectedIndexProvider = StateProvider<int>((ref) => 1); // Default to ChatScreen (now index 1)

class AppShell extends ConsumerStatefulWidget {
  AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Initialize page controller with the initial page from the provider
    _pageController = PageController(initialPage: ref.read(appShellSelectedIndexProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPageIndex = ref.watch(appShellSelectedIndexProvider);
    final theme = Theme.of(context); // Get theme for icon colors etc.

    // Ensure PageController is synced if selectedPageIndex changes from external source
    // This listener will react to changes in the provider and jump the page controller.
    ref.listen<int>(appShellSelectedIndexProvider, (previous, next) {
      if (next != _pageController.page?.round()) {
        _pageController.jumpToPage(next);
      }
    });

    final List<Widget> screens = [
      const HistoryListScreen(),  // Index 0
      const ChatScreen(),         // Index 1
      const SettingsScreen(),     // Index 2
    ];

    // The selectedPageIndex from the provider now directly corresponds to the
    // desired navBarIconIndex because the page order matches the navbar item order.
    // History (Page 0) -> NavBar Item 0
    // Chat    (Page 1) -> NavBar Item 1
    // Settings(Page 2) -> NavBar Item 2
    // No separate navBarIconIndex calculation is needed.

    // Define icon colors for dynamic styling
    Color selectedIconColor = Colors.white; // White icon on nearBlack button background
    Color unselectedIconColor = theme.colorScheme.onSurface.withOpacity(0.7); // Darker icon on darkSurface bar

    // Dynamically create items list with correct colors and borders
    List<Widget> navBarItems = [
      _buildNavItem(context, FeatherIcons.list, selectedPageIndex == 0, selectedIconColor, unselectedIconColor),
      _buildNavItem(context, FeatherIcons.plus, selectedPageIndex == 1, selectedIconColor, unselectedIconColor),
      _buildNavItem(context, FeatherIcons.settings, selectedPageIndex == 2, selectedIconColor, unselectedIconColor),
    ];

    return Scaffold(
      extendBody: true, // Allow body to extend behind the navbar
      body: PageView( // PageView directly in the body
            controller: _pageController,
            onPageChanged: (index) {
              ref.read(appShellSelectedIndexProvider.notifier).state = index;
            },
            children: screens,
          ),
      // Move CurvedNavigationBar back to the bottomNavigationBar slot
      bottomNavigationBar: CurvedNavigationBar(
          index: selectedPageIndex, 
          height: 65.0, 
          items: navBarItems,
          color: AppColors.kopyaPurple, // USING AppColors.kopyaPurple for the bar
          buttonBackgroundColor: AppColors.kopyaPurple, // This was already kopyaPurple
          backgroundColor: Colors.transparent, // Make the area behind the curve transparent
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 400),
          onTap: (tappedIconIndex) {
            if (tappedIconIndex == 1) { // Chat/Plus icon tapped
              ref.read(chatProvider.notifier).clearCurrentSessionId();
            }
            
            ref.read(appShellSelectedIndexProvider.notifier).state = tappedIconIndex;
          },
          letIndexChange: (index) => true,
        ),
    );
  }

  // Helper method to build nav items with borders
  Widget _buildNavItem(BuildContext context, IconData icon, bool isSelected, Color selectedColor, Color unselectedColor) {
    // Determine icon color FIRST
    Color iconColor = isSelected ? selectedColor : unselectedColor;

    // Determine decoration based on selection
    BoxDecoration? decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        // Selected item's own background - make it solid for visibility
        color: AppColors.kopyaPurple, // Solid primary color for selected item
        shape: BoxShape.circle,
      );
    }

    return Container(
      padding: const EdgeInsets.all(4.0), // Padding around the icon
      decoration: decoration, // Apply decoration only if selected
      child: Icon(
        icon,
        size: 26,
        color: iconColor,
      ),
    );
  }
} 