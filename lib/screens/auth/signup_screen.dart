import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
// import 'login_screen.dart'; // Will be needed for navigation

// Get a reference to the Supabase client
final supabase = Supabase.instance.client;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Optional: Add a confirm password field if desired
  // final _confirmPasswordController = TextEditingController(); 
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (mounted) {
          if (response.user != null) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign up successful! Please check your email to confirm your account.')),
            );
            // Optionally, navigate to login screen or show a specific "check email" page
            if (Navigator.canPop(context)) Navigator.pop(context); // Go back to login
          } else {
            // This case might occur if email confirmation is disabled and sign-up is immediate,
            // or if there's an issue not caught as an error but user is null.
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign up completed, but user data is not immediately available. Please try logging in.')),
            );
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign up failed: ${e.message}'), backgroundColor: Colors.redAccent),
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
    // if (_confirmPasswordController != null) _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32.0),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) { // Basic email validation
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) { // Example: Basic password length validation
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                // Optional: Confirm Password Field
                // const SizedBox(height: 16.0),
                // TextFormField(
                //   controller: _confirmPasswordController,
                //   decoration: const InputDecoration(
                //     labelText: 'Confirm Password',
                //     border: OutlineInputBorder(),
                //     prefixIcon: Icon(Icons.lock_outline),
                //   ),
                //   obscureText: true,
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Please confirm your password';
                //     }
                //     if (value != _passwordController.text) {
                //       return 'Passwords do not match';
                //     }
                //     return null;
                //   },
                // ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0)
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text('Sign Up'),
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () {
                        // Navigate back to LoginScreen
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          // Fallback if not pushed (e.g. if it was the initial route, though unlikely here)
                          // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Login screen navigation to be implemented if not popped.')),
                          );
                        }
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 