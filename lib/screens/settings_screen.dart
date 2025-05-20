import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:eli5/main.dart'; // Import main.dart to access themeModeProvider - Not needed currently
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
import 'package:url_launcher/url_launcher.dart'; // Added import
import 'package:purchases_flutter/purchases_flutter.dart'; // Added RevenueCat import
import 'dart:io'; // For Platform.isIOS or Platform.isAndroid
import 'package:eli5/providers/chat_provider.dart'; // For chatProvider
import 'package:eli5/providers/revenuecat_provider.dart'; // Import the new provider
import 'package:eli5/utils/snackbar_helper.dart'; // ADDED
import 'package:eli5/screens/paywall_screen.dart'; // ADDED for navigation
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
        showStyledSnackBar(context, message: 'Could not launch $urlString', isError: true);
      }
    }
  }

  // Keep the signOut method
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client.auth.signOut();
      await Purchases.logOut();
      print('RevenueCat: Logged out');

      // Invalidate providers that hold user-specific data
      ref.invalidate(chatSessionsProvider); 
      // If you have other providers holding user-specific data (e.g., user profile), invalidate them too.
      // Example: ref.invalidate(userProfileProvider);
      ref.read(chatProvider.notifier).clearCurrentSessionId(); // Also clear any active chat session from the previous user

      if (context.mounted) {
        showStyledSnackBar(context, message: 'Successfully logged out.');
        // AuthGate should handle navigation
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        showStyledSnackBar(context, message: 'Logout failed: ${e.message}', isError: true);
      }
    } catch (e) {
      if (context.mounted) {
        showStyledSnackBar(context, message: 'An unexpected error occurred during logout: ${e.toString()}', isError: true);
      }
    }
  }

  // Method to handle password reset for logged-in user
  Future<void> _resetPassword(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      showStyledSnackBar(context, message: 'Could not identify user. Please log in again.', isError: true);
      return;
    }

    // It's good practice to ask for confirmation before sending a reset email
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset Password?'),
          content: Text('A password reset link will be sent to ${user.email}.\nDo you want to continue?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Send Link'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          user.email!,
          // IMPORTANT: Configure this redirect URL in your Supabase dashboard under Auth -> URL Configuration -> Redirect URLs
          // It should also be handled by your app's deep linking setup.
          redirectTo: 'com.ahenyagan.eli5://login-callback?type=recovery', 
        );
        if (context.mounted) {
          showStyledSnackBar(context, message: 'Password reset link sent to ${user.email}. Please check your inbox.', duration: const Duration(seconds: 5));
        }
      } catch (e) {
        if (context.mounted) {
          showStyledSnackBar(context, message: 'Failed to send password reset link: ${e.toString()}', isError: true, duration: const Duration(seconds: 5));
        }
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

            // Account Management Section (New or merged with existing 'Account')
            if (user != null) ...[
              _buildSectionTitle(context, 'Account Management'),
              _buildSettingsListTile(
                context,
                icon: FeatherIcons.lock,
                title: 'Reset Password',
                onTap: () {
                  _resetPassword(context);
                },
              ),
            ],

            // Subscription Section
            _buildSectionTitle(context, 'Subscription'),
            ref.watch(customerInfoProvider).when(
              data: (customerInfo) {
                // Use the correct entitlement ID from RevenueCat
                final bool isSubscribed = customerInfo.entitlements.all['Access']?.isActive ?? false;
                
                if (isSubscribed) {
                  return _buildSettingsListTile(
                    context,
                    icon: FeatherIcons.creditCard,
                    title: 'Manage Subscription',
                    onTap: () async {
                      try {
                        // final customerInfo = await Purchases.getCustomerInfo(); // Already have it
                        String? managementURL = customerInfo.managementURL;

                        if (managementURL != null && managementURL.isNotEmpty) {
                          _launchURL(context, managementURL);
                        } else {
                          // Fallback to store-specific URLs
                          String storeURL = '';
                          if (Platform.isIOS) {
                            storeURL = 'https://apps.apple.com/account/subscriptions';
                          } else if (Platform.isAndroid) {
                            storeURL = 'https://play.google.com/store/account/subscriptions';
                          } else {
                             if (context.mounted) {
                              showStyledSnackBar(context, message: 'Subscription management not available on this platform.', isError: true);
                            }
                            return;
                          }
                          _launchURL(context, storeURL);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showStyledSnackBar(context, message: 'Could not open subscription management: ${e.toString()}', isError: true);
                          // As a last resort, try the generic Play Store subscription link for Android if error occurred before platform check.
                          if (Platform.isAndroid) {
                             _launchURL(context, 'https://play.google.com/store/account/subscriptions');
                          } else if (Platform.isIOS) {
                             _launchURL(context, 'https://apps.apple.com/account/subscriptions');
                          }
                        }
                      }
                    },
                  );
                } else {
                  // Optionally, show a button to subscribe or some info if not subscribed
                  return _buildSettingsListTile(
                    context,
                    icon: FeatherIcons.shoppingCart, // Or some other icon
                    title: 'View Subscription Options', // Or 'Subscribe Now'
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaywallScreen(
                            onContinueToApp: () {
                              // If PaywallScreen is dismissed without purchase from Settings,
                              // simply pop back to SettingsScreen.
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                }
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('Error: Could not load subscription status.', style: TextStyle(color: theme.colorScheme.error))),
              ),
            ),
            
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
                     showStyledSnackBar(context, message: 'Auth screen navigation not implemented yet.', isError: true);
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
      showStyledSnackBar(context, message: '$title tapped. Action not yet implemented.');
    },
    contentPadding: EdgeInsets.zero,
  );
} 