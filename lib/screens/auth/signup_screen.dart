import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
import 'package:eli5/utils/snackbar_helper.dart'; // ADDED
// import 'auth_screen.dart'; // Import for tab navigation maybe later
// import 'login_screen.dart'; // Will be needed for navigation

// Get a reference to the Supabase client
final supabase = Supabase.instance.client;

// --- Sign Up Form Widget ---
class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({super.key});

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final AuthResponse response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (mounted) {
          // If signUp completes without an AuthException, Supabase has processed the request.
          // This covers new users (confirmation email sent) and existing users 
          // (confirmation email re-sent, which will log them in upon clicking).
          // Based on extensive testing, we cannot reliably distinguish an *already confirmed* 
          // user from a new/unconfirmed one solely from the signUp response 
          // (emailConfirmedAt is null, and no specific "already exists" exception is consistently thrown for this case).
          showStyledSnackBar(context, message: 'Sign up attempt processed. Please check your email to confirm your account or log in.');
        }
      } on AuthException catch (e) {
        if (mounted) {
          String errorMessage = e.message;
          // Handle specific known errors like rate limiting
          if (e.statusCode == 429) { 
            errorMessage = 'Too many sign-up attempts. Please try again later.';
          }
          // For other AuthExceptions, display their message.
          // We are no longer trying to specifically catch "user already exists" here because
          // it doesn't seem to be thrown reliably for already-confirmed users during signUp.
          showStyledSnackBar(context, message: errorMessage, isError: true);
        }
      } catch (e) {
        if (mounted) {
          showStyledSnackBar(context, message: 'An unexpected error occurred: ${e.toString()}', isError: true);
        }
      }
      if (mounted) {
         setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Match styling from inspiration image
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24.0), // Padding for the form content
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Create Account',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              // textAlign: TextAlign.center, // Center if needed
            ),
            const SizedBox(height: 8),
            Text(
              'Let\'s get started by filling out the form below.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              // textAlign: TextAlign.center, // Center if needed
            ),
            const SizedBox(height: 32.0),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                // labelText: 'Email', // Use hintText for this style
                hintText: 'Email',
                // prefixIcon: Icon(FeatherIcons.mail), // Icons inside look clunky with pill shape
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter your email';
                if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$").hasMatch(value)) {
                   return 'Please enter a valid email address';
                 }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                // labelText: 'Password',
                hintText: 'Password',
                // prefixIcon: Icon(FeatherIcons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? FeatherIcons.eyeOff : FeatherIcons.eye,
                    size: 20,
                    color: theme.iconTheme.color?.withAlpha(150)
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter your password';
                if (value.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Get Started'),
            ),
            const SizedBox(height: 32.0),
            // TODO: Add "Or sign up with" + Social Buttons later
            // Row(...) Divider(...) Row(...)
            // OutlinedButton.icon(...) etc.
            const SocialSignInButtons(dividerText: 'Or sign up with'), // Pass the text
          ],
        ),
      ),
    );
  }
}

// --- Social Sign In Buttons Widget ---
class SocialSignInButtons extends StatelessWidget {
  final String dividerText;
  const SocialSignInButtons({super.key, required this.dividerText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 24.0),
        Row(
          children: [
            const Expanded(child: Divider(thickness: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                dividerText,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const Expanded(child: Divider(thickness: 0.5)),
          ],
        ),
        const SizedBox(height: 24.0),
        OutlinedButton(
          onPressed: () async {
            // TODO: Implement Google Sign-In
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(content: Text('Google Sign-In not implemented yet.')),
            // );
            try {
              await Supabase.instance.client.auth.signInWithOAuth(
                OAuthProvider.google,
                redirectTo: kIsWeb ? null : 'com.ahenyagan.eli5://auth-ca/',
              );
              // AuthGate will handle navigation if successful
            } catch (e) {
              if (context.mounted) {
                showStyledSnackBar(context, message: 'Google Sign-In Failed: ${e.toString()}', isError: true);
              }
            }
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Continue with Google'),
        ),
        const SizedBox(height: 12.0),
        OutlinedButton(
           onPressed: () async {
            // TODO: Implement Apple Sign-In
            //  ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(content: Text('Apple Sign-In not implemented yet.')),
            // );
            try {
              await Supabase.instance.client.auth.signInWithOAuth(
                OAuthProvider.apple,
                redirectTo: kIsWeb ? null : 'com.ahenyagan.eli5://auth-ca/', // Ensure this redirect is configured in Supabase & Apple Dev Console
              );
              // AuthGate will handle navigation
            } catch (e) {
              if (context.mounted) {
                showStyledSnackBar(context, message: 'Apple Sign-In Failed: ${e.toString()}', isError: true);
              }
            }
           },
           style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
           ),
           child: const Text('Continue with Apple'),
        ),
      ],
    );
  }
}

// Keep the original SignUpScreen as a simple wrapper if needed for direct routing,
// but it will likely be removed or repurposed.
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up (Old)')), // Indicate it's old
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: SignUpForm(), // Display the extracted form
        ),
      ),
    );
  }
} 