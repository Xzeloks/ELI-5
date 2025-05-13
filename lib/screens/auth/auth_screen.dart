import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'signup_screen.dart'; // Import the file containing SignUpForm
import 'login_screen.dart'; // Import the file containing LoginForm
// TODO: Import Login and Signup form widgets once created/extracted - DONE

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Background color could be set here if needed, e.g., theme.colorScheme.background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Placeholder for ELI-5 Branding/Logo Area
              const SizedBox(height: 60),
              Text(
                'ELI-5', 
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Tab Bar Implementation
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow.withAlpha(150), // Use M3 surface role
                  borderRadius: BorderRadius.circular(25.0), // Rounded background for tabs
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25.0),
                    color: theme.colorScheme.primary, // Accent color for indicator
                  ),
                  indicatorColor: Colors.transparent,
                  indicatorWeight: 0.0,
                  dividerColor: Colors.transparent,
                  labelColor: theme.colorScheme.onPrimary, // Text color for selected tab
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant, // Text color for unselected tabs
                  labelStyle: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold), // Adjust style as needed
                  unselectedLabelStyle: theme.textTheme.bodyLarge, // Adjust style as needed
                  indicatorSize: TabBarIndicatorSize.tab, // Makes indicator fill the tab background
                  tabs: const [
                    Tab(text: 'Create Account'),
                    Tab(text: 'Log In'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab Bar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    // Placeholder for SignUp Form
                    // Center(child: Text('Sign Up Form Area')), 
                    SignUpForm(), // Use the extracted SignUpForm widget
                    
                    // Placeholder for Login Form
                    // Center(child: Text('Log In Form Area')), 
                    LoginForm(), // Use the extracted LoginForm widget
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 