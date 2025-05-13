import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
// import 'auth_screen.dart'; // Import for tab navigation maybe later - UNUSED
import 'signup_screen.dart'; // Import needed for SocialSignInButtons defined in signup_screen.dart

// Get a reference to the Supabase client
final supabase = Supabase.instance.client;

// --- Log In Form Widget ---
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // AuthGate will handle navigation on successful login
        if (mounted && response.user == null) {
           // If sign in completes but user is somehow null (should be caught by AuthException generally)
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed: Unknown error.'), backgroundColor: Colors.redAccent),
          );
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: ${e.message}'), backgroundColor: Colors.redAccent),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: ${e.toString()}'), backgroundColor: Colors.redAccent),
          );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
             Text(
              'Welcome Back!', // Or just "Log In"?
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your details below to continue.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32.0),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'Email',
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
                hintText: 'Password',
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
                return null;
              },
            ),
            // TODO: Add Forgot Password? button/link if desired
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Log In'),
            ),
            const SizedBox(height: 32.0),
            // TODO: Add "Or sign in with" + Social Buttons later
            const SocialSignInButtons(dividerText: 'Or sign in with'), // Add social buttons
          ],
        ),
      ),
    );
  }
}

// Keep the original LoginScreen as a simple wrapper if needed for direct routing,
// but it will likely be removed or repurposed.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In (Old)')), // Indicate it's old
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: LoginForm(), // Display the extracted form
        ),
      ),
    );
  }
} 