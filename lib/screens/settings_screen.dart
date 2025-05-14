import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:eli5/main.dart'; // Import main.dart to access themeModeProvider - Not needed currently
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
import 'package:url_launcher/url_launcher.dart'; // Added import
import 'package:purchases_flutter/purchases_flutter.dart'; // Added RevenueCat import
import 'dart:io'; // For Platform.isIOS or Platform.isAndroid
import 'package:eli5/providers/chat_provider.dart'; // For chatProvider
// Removed incorrect imports for settings_provider and auth_provider

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Helper function to launch URLs
  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  // Keep the signOut method
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client.auth.signOut();

      // Invalidate providers that hold user-specific data
      ref.invalidate(chatSessionsProvider); 
      // If you have other providers holding user-specific data (e.g., user profile), invalidate them too.
      // Example: ref.invalidate(userProfileProvider);
      ref.read(chatProvider.notifier).clearCurrentSessionId(); // Also clear any active chat session from the previous user

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
            // const Divider(height: 32, thickness: 0.5), // Removed

            // Subscription Section
            // _buildSectionTitle(context, 'Subscription'),
            // _buildSettingsListTile(
            //   context,
            //   icon: FeatherIcons.creditCard,
            //   title: 'Manage Subscription',
            //   onTap: () async {
            //     try {
            //       final customerInfo = await Purchases.getCustomerInfo();
            //       String? managementURL = customerInfo.managementURL;

            //       if (managementURL != null && managementURL.isNotEmpty) {
            //         _launchURL(context, managementURL);
            //       } else {
            //         // Fallback to store-specific URLs
            //         String storeURL = '';
            //         if (Platform.isIOS) {
            //           storeURL = 'https://apps.apple.com/account/subscriptions';
            //         } else if (Platform.isAndroid) {
            //           storeURL = 'https://play.google.com/store/account/subscriptions';
            //         } else {
            //            if (context.mounted) {
            //             ScaffoldMessenger.of(context).showSnackBar(
            //               const SnackBar(content: Text('Subscription management not available on this platform.')),
            //             );
            //           }
            //           return;
            //         }
            //         _launchURL(context, storeURL);
            //       }
            //     } catch (e) {
            //       if (context.mounted) {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           SnackBar(content: Text('Could not open subscription management: ${e.toString()}')),
            //         );
            //         // As a last resort, try the generic Play Store subscription link for Android if error occurred before platform check.
            //         if (Platform.isAndroid) {
            //            _launchURL(context, 'https://play.google.com/store/account/subscriptions');
            //         } else if (Platform.isIOS) {
            //            _launchURL(context, 'https://apps.apple.com/account/subscriptions');
            //         }
            //       }
            //     }
            //   },
            // ),
            // const Divider(height: 32, thickness: 0.5), // Removed

            // Help & Feedback Section
            _buildSectionTitle(context, 'Help & Feedback'),
            _buildSettingsListTile(
              context,
              icon: FeatherIcons.helpCircle,
              title: 'Report a Bug',
              onTap: () {
                // TODO: Implement bug reporting
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'ahen@gentartgrup.com.tr',
                  queryParameters: {
                    'subject': 'ELI5 App Bug Report'
                  }
                );
                _launchURL(context, emailLaunchUri.toString());
              },
            ),
            _buildSettingsListTile(
              context,
              icon: FeatherIcons.mail,
              title: 'Contact Support',
              onTap: () {
                // TODO: Implement contact support
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'ahen@gentartgrup.com.tr',
                  queryParameters: {
                    'subject': 'ELI5 App Support Request'
                  }
                );
                _launchURL(context, emailLaunchUri.toString());
              },
            ),

            // About Section
            _buildSectionTitle(context, 'About'),
            _buildSettingsListTile(
              context,
              icon: FeatherIcons.shield,
              title: 'Privacy Policy',
              onTap: () {
                // TODO: Implement navigation to Privacy Policy
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Privacy Policy: Not implemented yet.')),
                // );
                _launchURL(context, 'https://xzeloks.github.io/ELI-5/PRIVACY_POLICY.html');
              },
            ),
            _buildSettingsListTile(
              context,
              icon: FeatherIcons.fileText,
              title: 'Terms of Service',
              onTap: () {
                // TODO: Implement navigation to Terms of Service
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Terms of Service: Not implemented yet.')),
                // );
                _launchURL(context, 'https://xzeloks.github.io/ELI-5/TERMS_OF_SERVICE.html');
              },
            ),
            const SizedBox(height: 24.0), // Added bottom padding for scroll aesthetics

            // Sign Out/Sign In Button (Moved to the bottom)
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0), // Add some space above the button
                child: Center(
                child: ElevatedButton.icon(
                  icon: Icon(FeatherIcons.logOut, size: 18, color: theme.colorScheme.error),
                  label: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
                    onPressed: () => _signOut(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.3),
                    foregroundColor: theme.colorScheme.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 24.0), // Add some space above the button
                child: Center(
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
              ),
            const SizedBox(height: 16.0), // Ensure some padding at the very bottom
          ],
        ),
      ),
    );
  }
}

// Helper widget for section titles
Widget _buildSectionTitle(BuildContext context, String title) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
    child: Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// Helper widget for list tiles
Widget _buildSettingsListTile(BuildContext context, {required IconData icon, required String title, VoidCallback? onTap}) {
  final theme = Theme.of(context);
  return ListTile(
    leading: Icon(icon, color: theme.iconTheme.color),
    title: Text(title),
    trailing: const Icon(FeatherIcons.chevronRight),
    onTap: onTap ?? () {
      // Default action if onTap is null
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title tapped. Action not yet implemented.')),
      );
    },
    contentPadding: EdgeInsets.zero,
  );
} 