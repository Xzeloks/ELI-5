import 'dart:async'; // For StreamSubscription

import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // PlatformException might not be needed for app_links in basic usage
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:eli5/screens/auth/login_screen.dart'; // No longer needed
import 'package:eli5/screens/auth/auth_screen.dart'; // Import the new AuthScreen
// import 'package:eli5/screens/chat_screen.dart';
import 'package:eli5/screens/app_shell.dart';
// purchases_flutter is still needed for core functionalities like getCustomerInfo if used elsewhere, 
// but not directly for presentPaywallIfNeeded from RevenueCatUI.
// import 'package:purchases_flutter/purchases_flutter.dart' as purchases_flutter;
// import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // Import RevenueCat UI package
import 'package:app_links/app_links.dart'; // Import app_links
import 'package:eli5/widgets/onboarding/app_breakdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  bool _showAppBreakdown = false;
  bool _isLoadingBreakdownState = true; // Start as true

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initLinkListener();
    _checkIfShowBreakdown();
  }

  Future<void> _checkIfShowBreakdown() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool(hasSeenAppBreakdownKey) ?? false;
    if (mounted) {
      setState(() {
        _showAppBreakdown = !hasSeen;
        _isLoadingBreakdownState = false;
      });
    }
  }

  void _initLinkListener() {
    // Listen for all links, including the initial one if the app was opened via a link.
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (mounted) {
        print('AuthGate: Received URI via app_links: $uri');
        final String linkString = uri.toString();

        // Check if the link string contains Supabase auth tokens in the fragment
        if (linkString.contains('#access_token=') && linkString.contains('refresh_token=')) {
          print('AuthGate: Link appears to be a Supabase auth callback. Explicitly attempting to recover session.');
          Supabase.instance.client.auth.recoverSession(linkString).then((response) {
            // If the recoverSession call itself was successful (no exception thrown by the Future),
            // we check if a session was actually established.
            if (response.session != null && response.user != null) {
              print('AuthGate: Explicit recoverSession call successful and session established. AuthState should change.');
              // onAuthStateChange listener in StreamBuilder will handle navigation
            } else {
              // This case means the API call was successful but Supabase couldn't establish a session (e.g., invalid tokens).
              print('AuthGate: Explicit recoverSession call completed, but no session was established. Potential token issue.');
              // Optionally, show a user-facing error SnackBar here if desired
              // AppSnackbar.showError(context, 'Failed to process login link. Please try again or contact support.');
            }
          }).catchError((error) { // Catches errors from the Future itself (e.g., network errors)
            print('AuthGate: Exception/Error during explicit recoverSession call: $error');
            // Optionally, show a user-facing error SnackBar here
            // AppSnackbar.showError(context, 'Error processing login link: $error');
          });
        } else {
          print('AuthGate: Received URI does not appear to be a Supabase auth callback. URI: $uri');
        }
      }
    }, onError: (err) {
      if (mounted) {
        print('AuthGate: Error on uriLinkStream: $err');
        // Optionally, show a user-facing error SnackBar here
        // AppSnackbar.showError(context, 'Error receiving app link: $err');
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show a loading indicator while waiting for the auth state OR breakdown state
        if (snapshot.connectionState == ConnectionState.waiting || _isLoadingBreakdownState) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final session = snapshot.data?.session;

        if (session != null) {
          if (_showAppBreakdown) {
            return AppBreakdownScreen(
              onFinished: () {
                if (mounted) {
                  setState(() {
                    _showAppBreakdown = false; 
                    // The AppBreakdownScreen itself handles setting the shared_pref if "don't show again" is checked.
                  });
                }
              },
            );
          }
          return AppShell(); 
        } else {
          // If user logs out, reset the breakdown flag so they see it again if they log back in as a *new* user
          // or if we decide to show it per login session rather than once ever per device.
          // For now, we'll keep it simple: it only shows once ever until prefs are cleared or "don't show again" is unchecked.
          // If _showAppBreakdown was true, and session becomes null, we should probably hide it.
          // However, the primary control is shared_prefs for *next* time.
          // If they were seeing breakdown, then logged out, _showAppBreakdown might still be true.
          // So, ensure if session is null, _showAppBreakdown doesn't force it.
          // The outer if (session != null) handles this.
          return const AuthScreen();
        }
      },
    );
  }
} 