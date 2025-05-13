import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:eli5/main.dart'; // Import main.dart to access themeModeProvider - Not needed currently
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
// Removed incorrect imports for settings_provider and auth_provider

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Keep the signOut method
  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully logged out.')),
        );
        // AuthGate should handle navigation
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.message}'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred during logout: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get user directly from Supabase instance
    final user = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      // Assuming no AppBar is needed here as it might be in AppShell
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            // Add SizedBox for top padding (32.0)
            const SizedBox(height: 32.0),
            // Display User Info
            Text(
              'Account',
              style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (user != null)
              ListTile(
                leading: Icon(FeatherIcons.user, color: theme.iconTheme.color),
                title: const Text('Logged In As'),
                subtitle: Text(user.email ?? 'No email available'),
                contentPadding: EdgeInsets.zero,
              )
            else
              const ListTile(
                leading: Icon(FeatherIcons.alertCircle),
                title: Text('Not Logged In'),
                contentPadding: EdgeInsets.zero,
              ),
            const Divider(height: 32, thickness: 0.5),
            // Sign Out Button
            if (user != null)
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(FeatherIcons.logOut, size: 18, color: theme.colorScheme.error),
                  label: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
                  onPressed: () => _signOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.3),
                    foregroundColor: theme.colorScheme.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              )
            else
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(FeatherIcons.logIn, size: 18),
                  label: const Text('Sign In / Sign Up'),
                  onPressed: () {
                     // Ideally navigate to AuthScreen or show modal
                     print("Navigate to Auth Screen triggered from Settings");
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Auth screen navigation not implemented yet.')),
                      );
                  },
                  // Add style if needed
                ),
              ),
            // Add other settings sections below if needed in the future
          ],
        ),
      ),
    );
  }
}

// Removed the helper widgets (_ApiKeyTile, _AuthCard) that depended on the non-existent providers 