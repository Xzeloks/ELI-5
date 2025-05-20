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
import 'package:eli5/screens/paywall_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:eli5/providers/revenuecat_provider.dart'; // Import your provider
import 'package:purchases_flutter/purchases_flutter.dart'; // Import Purchases
import 'package:eli5/screens/auth/new_password_screen.dart'; // Placeholder for NewPasswordScreen

const String hasSeenPaywallKey = 'hasSeenPaywall';
// const String hasSeenAppBreakdownKey = 'hasSeenAppBreakdown'; // Already in app_breakdown_screen.dart

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription; // ADDED for more direct auth state handling

  bool _showAppBreakdown = false; 
  bool _isLoadingStates = true; 
  bool _isInPasswordRecoveryMode = false; // ADDED state for password recovery

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initLinkListener();
    _checkInitialStates();

    // Subscribe to auth state changes more directly
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((AuthState data) {
      if (!mounted) return;
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      final bool previousRecoveryMode = _isInPasswordRecoveryMode; // Capture state before potential change
      print("[AuthGate] onAuthStateChange event: $event, session: ${session != null}, wasInRecovery: $previousRecoveryMode, newSessionUser: ${session?.user?.id}");

      if (event == AuthChangeEvent.passwordRecovery) {
        print("[AuthGate] Password recovery event detected. Entering recovery mode.");
        setState(() {
          _isInPasswordRecoveryMode = true;
        });
      } else if (previousRecoveryMode && (event == AuthChangeEvent.userUpdated || event == AuthChangeEvent.signedIn)) {
        // If we were in recovery mode and the user is updated (password changed) or signed in,
        // it's time to exit recovery mode and let the main StreamBuilder handle redirection (likely to login).
        print("[AuthGate] UserUpdated or SignedIn event while in recovery mode. Exiting recovery mode. Event: $event");
        setState(() {
          _isInPasswordRecoveryMode = false;
        });
      } else if (event == AuthChangeEvent.signedOut) {
        // If user signs out, ensure they are not in password recovery mode.
        print("[AuthGate] SignedOut event. Exiting recovery mode if active.");
        if (previousRecoveryMode) { // only change state if it was true
           setState(() {
            _isInPasswordRecoveryMode = false;
          });
        }
      }
      // Other events like signedIn (not in recovery), tokenRefreshed will cause StreamBuilder to rebuild.
    }, onError: (error) {
      print("[AuthGate] onAuthStateChange error: $error");
    });
  }

  Future<void> _checkInitialStates() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenBreakdown = prefs.getBool(hasSeenAppBreakdownKey) ?? false;
    if (mounted) {
      setState(() {
        _showAppBreakdown = !hasSeenBreakdown;
        _isLoadingStates = false;
      });
    }
  }

  Future<void> _markPaywallAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenPaywallKey, true);
    // No direct setState for a _shouldShowPaywall flag needed here anymore,
    // the UI will rebuild based on the FutureBuilder checking SharedPreferences.
    // However, if PaywallScreen pops or calls this, the parent AuthGate might need to rebuild
    // to move to AppShell. In many cases, the navigation from PaywallScreen will handle this.
    // Forcing a rebuild if necessary:
    if (mounted) {
        setState(() {});
    }
  }

  void _initLinkListener() {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (!mounted) return;
      print('AuthGate: Received link: $uri');
      if (uri.pathSegments.contains('auth-callback')) {
        print('AuthGate: Auth callback link detected. Supabase should handle it.');
      }
    }, onError: (err) {
      if (mounted) {
        print('AuthGate: Error on uriLinkStream: $err');
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel(); // ADDED: Cancel the auth subscription
    super.dispose();
  }

  Future<void> _handleUserSession(User supabaseUser) async {
    try {
      final String? currentRCAppUserID = await Purchases.appUserID;
      if (currentRCAppUserID != supabaseUser.id) {
        await Purchases.logIn(supabaseUser.id);
        print('RevenueCat: Logged in user ${supabaseUser.id}');
        ref.invalidate(customerInfoProvider); // Invalidate to refetch with new user ID
      } else {
        // If user is already logged in to RC with the same ID, 
        // still good to refresh customerInfo in case entitlements changed.
        // However, ref.watch will already rebuild if underlying data changes and provider re-evaluates.
        // Explicit invalidation can be done if there are edge cases where it doesn't pick up.
        // For now, let's assume if IDs match, subsequent ref.watch will be fine.
         ref.read(customerInfoProvider.future); // Ensure it attempts to fetch if not already
      }
    } catch (e) {
      print('RevenueCat: Error logging in user ${supabaseUser.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If in password recovery mode, show the NewPasswordScreen immediately.
    print("[AuthGate] Build method called. _isInPasswordRecoveryMode: $_isInPasswordRecoveryMode, _isLoadingStates: $_isLoadingStates");
    if (_isInPasswordRecoveryMode) {
      print("[AuthGate] In password recovery mode, showing NewPasswordScreen.");
      // Removed onPasswordUpdated callback. NewPasswordScreen handles its own navigation.
      // AuthGate will react to onAuthStateChange (e.g., userUpdated or subsequent signedIn)
      return const NewPasswordScreen();
    }

    // Continue with the existing StreamBuilder for onAuthStateChange for other auth states.
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting || _isLoadingStates) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final AuthState? authStateData = authSnapshot.data;
        final AuthChangeEvent? event = authStateData?.event;
        final Session? session = authStateData?.session;

        print("[AuthGate] StreamBuilder: event: $event, session: ${session != null}, user: ${session?.user?.id}, _isInPasswordRecoveryMode: $_isInPasswordRecoveryMode");

        // The _isInPasswordRecoveryMode check at the top of build() handles this case primarily.
        // This additional check is mostly for logging or if the direct subscription was missed.
        if (event == AuthChangeEvent.passwordRecovery && !_isInPasswordRecoveryMode) {
           print("[AuthGate] StreamBuilder detected Password recovery event. Should be handled by _authSubscription. Forcing _isInPasswordRecoveryMode = true");
           // It's possible the direct subscription sets the flag, and this builder runs before the next setState cycle.
           // In such a case, returning a loading indicator or deferring to the flag is safer.
           // For now, the top-level check for _isInPasswordRecoveryMode is the primary gate.
           // However, if missed, we set it and show loading to allow rebuild.
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted && !_isInPasswordRecoveryMode) { // Check again to avoid race if subscription already ran
                setState(() { _isInPasswordRecoveryMode = true; });
             }
           });
           return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Processing recovery...")));
        }

        if (session != null) {
          // Call _handleUserSession without awaiting it in build, 
          // but let it run. UI will react via provider changes.
          // Using a FutureBuilder to manage the _handleUserSession call state before rendering UI dependent on it.
          return FutureBuilder(
            future: _handleUserSession(session.user), // Pass session.user here
            builder: (context, snapshotSessionHandling) {
              if (snapshotSessionHandling.connectionState == ConnectionState.waiting) {
                 return const Scaffold(body: Center(child: Text("Setting up session..."))); // Or your main loading indicator
              }
              // After session handling (login to RC), proceed to watch customerInfo
              final customerInfoAsync = ref.watch(customerInfoProvider);
              return customerInfoAsync.when(
                data: (customerInfo) {
                  final bool isSubscribed = customerInfo.entitlements.all['Access']?.isActive ?? false;
                  
                  if (isSubscribed) {
                    print("[AuthGate] User is subscribed. Navigating to AppShell.");
                    return AppShell();
                  } else { // Not subscribed
                    print("[AuthGate] User is NOT subscribed.");
                    if (_showAppBreakdown) {
                      print("[AuthGate] Showing AppBreakdownScreen.");
                      return AppBreakdownScreen(
                        onFinished: () async {
                          if (mounted) {
                            setState(() {
                              _showAppBreakdown = false;
                            });
                            // After AppBreakdown, logic will fall through to show PaywallScreen
                            // as isSubscribed is still false.
                          }
                        },
                      );
                    } else {
                      // Not subscribed and AppBreakdown is done (or was skipped)
                      print("[AuthGate] Showing PaywallScreen.");
                      return PaywallScreen(
                        onContinueToApp: () async {
                          // This callback is typically invoked if PaywallScreen had a
                          // "continue without purchase" or "trial" button that doesn't immediately grant entitlement
                          // but should mark the paywall as 'interacted with'.
                          // For a strict "subscribe to use" model, this might be less critical
                          // if the only way forward is a successful purchase (which updates customerInfo).
                          print("[AuthGate] PaywallScreen.onContinueToApp invoked.");
                          await _markPaywallAsSeen(); 
                          if (mounted) {
                            // This setState might be redundant if customerInfoProvider invalidation
                            // after a purchase is the primary way to rebuild AuthGate.
                            // However, keeping it for now if _markPaywallAsSeen influences other logic.
                            setState(() {}); 
                          }
                        },
                      );
                    }
                  }
                },
                loading: () {
                  print("[AuthGate] CustomerInfo loading. Showing loading indicator.");
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                },
                error: (err, stack) {
                  print('[AuthGate] Error fetching customer info: $err. Fallback logic will apply.');
                  // Fallback logic: if error fetching customerInfo, still show AppBreakdown or Paywall
                  // This prevents users from getting stuck if RC has an issue but they are otherwise authenticated.
                  // The assumption is they are "not subscribed" if we can't verify.
                  if (_showAppBreakdown) {
                    print("[AuthGate] Error fetching CustomerInfo, showing AppBreakdownScreen.");
                     return AppBreakdownScreen(
                        onFinished: () => setState(() => _showAppBreakdown = false)
                    );
                  }
                  // If error and no AppBreakdown, show Paywall as a fallback
                  print("[AuthGate] Error fetching CustomerInfo, showing PaywallScreen as fallback.");
                  return PaywallScreen(
                    onContinueToApp: () async {
                      await _markPaywallAsSeen();
                       if (mounted) {
                        setState(() {});
                      }
                    },
                  );
                },
              );
            }
          );
        } else {
          // No active session, show AuthScreen (Login/Signup)
          // Also, ensure we are not in password recovery mode if we reach here with a null session.
          if (_isInPasswordRecoveryMode) {
            print("[AuthGate] Session is null, but still in password recovery mode. This indicates a state to clear. Forcing exit from recovery.");
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if(mounted && _isInPasswordRecoveryMode){ // Check again to avoid race conditions
                 setState(() {
                   _isInPasswordRecoveryMode = false;
                 });
               }
            });
            // Return loading for one frame to allow state to update and then show AuthScreen.
            return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Finalizing password update...")));
          }
          print("[AuthGate] Session is null and not in password recovery. Navigating to AuthScreen.");
          return const AuthScreen();
        }
      },
    );
  }
} 