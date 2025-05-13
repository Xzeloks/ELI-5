import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:eli5/screens/auth/login_screen.dart'; // No longer needed
import 'package:eli5/screens/auth/auth_screen.dart'; // Import the new AuthScreen
// import 'package:eli5/screens/chat_screen.dart';
import 'package:eli5/screens/app_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
          // User is logged in, show AppShell (which defaults to ChatScreen)
          return AppShell();
        } else {
          // User is not logged in, show LoginScreen
          // return const LoginScreen();
          return const AuthScreen(); // Navigate to the new AuthScreen
        }
      },
    );
  }
} 