import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:eli5/screens/auth/login_screen.dart'; // No longer needed
import 'package:eli5/screens/auth/auth_screen.dart'; // Import the new AuthScreen
// import 'package:eli5/screens/chat_screen.dart';
import 'package:eli5/screens/app_shell.dart';
// purchases_flutter is still needed for core functionalities like getCustomerInfo if used elsewhere, 
// but not directly for presentPaywallIfNeeded from RevenueCatUI.
// import 'package:purchases_flutter/purchases_flutter.dart' as purchases_flutter;
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // Import RevenueCat UI package

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // Future<void> _presentPaywallIfNeeded() async {
  //   // TODO: Replace "premium" with your actual entitlement identifier from RevenueCat
  //   const String requiredEntitlement = "premium";

  //   try {
  //     // Using RevenueCatUI to present the paywall if needed
  //     await RevenueCatUI.presentPaywallIfNeeded(requiredEntitlement);
  //     print("Paywall check completed. Entitlement: $requiredEntitlement");
  //   } catch (e) {
  //     print("Error during presentPaywallIfNeeded: $e");
  //     // Handle error appropriately - e.g., if paywall presentation itself fails
  //     // For now, we let the app proceed.
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show a loading indicator while waiting for the auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Even if snapshot.hasData is true, session could still be null if user is logged out.
        final session = snapshot.data?.session;

        if (session != null) {
          // User is logged in, present paywall if needed, then show AppShell
          // return FutureBuilder<void>(
          //   future: _presentPaywallIfNeeded(),
          //   builder: (context, paywallSnapshot) {
          //     if (paywallSnapshot.connectionState == ConnectionState.waiting) {
          //       return const Scaffold(
          //         body: Center(child: CircularProgressIndicator(key: ValueKey("PaywallLoadingIndicator"))),
          //       );
          //     }
          //     // After paywall check (or if it failed but we decided to proceed),
          //     // show the main app content.
          //     return AppShell();
          //   },
          // );
          return AppShell(); // Directly return AppShell
        } else {
          // User is not logged in, show LoginScreen
          // return const LoginScreen();
          return const AuthScreen(); // Navigate to the new AuthScreen
        }
      },
    );
  }
} 