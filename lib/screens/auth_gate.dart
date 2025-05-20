import 'dart:async';
import 'package:eli5/screens/app_shell.dart';
import 'package:eli5/screens/auth/login_screen.dart';
// import 'package:eli5/screens/auth/new_password_screen.dart'; // Placeholder
import 'package:eli5/screens/auth/new_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart'; // Import app_links
import 'package:logging/logging.dart';

final _log = Logger('AuthGate');

class AuthGate extends StatefulWidget {
  static const routeName = '/auth-gate';
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _uriLinkSubscription;
  bool _isInPasswordRecoveryMode = false;
  bool _initialStateProcessed = false;
  final AppLinks _appLinks = AppLinks();
  Timer? _initialStateTimer; // Timer to prevent indefinite loading

  @override
  void initState() {
    super.initState();
    _log.info("AuthGate initState. _initialStateProcessed: $_initialStateProcessed, _isInPasswordRecoveryMode: $_isInPasswordRecoveryMode");

    _initDeepLinks();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _log.info("onAuthStateChange: ${data.event}, session: ${data.session?.accessToken != null ? 'exists' : 'null'}, current recovery: $_isInPasswordRecoveryMode");
      bool previousRecoveryMode = _isInPasswordRecoveryMode;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _log.info("AuthStateChange: Password recovery event.");
        if (mounted) {
          setState(() {
            _isInPasswordRecoveryMode = true;
            _initialStateProcessed = true; // Recovery event implies state is now known
          });
        }
      } else if (data.event == AuthChangeEvent.signedIn) {
        _log.info("AuthStateChange: SignedIn event.");
        if (mounted) {
          setState(() {
            // If signing in, we are no longer in password recovery mode.
            _isInPasswordRecoveryMode = false;
            _initialStateProcessed = true; // Auth state change implies initial state is known
          });
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        _log.info("AuthStateChange: SignedOut event.");
        if (mounted) {
          setState(() {
            _isInPasswordRecoveryMode = false; // Signed out, not in recovery.
            _initialStateProcessed = true; // Auth state change implies initial state is known
          });
        }
      } else if (data.event == AuthChangeEvent.userUpdated && previousRecoveryMode) {
          // If user is updated WHILE in recovery mode (e.g. after NewPasswordScreen submits)
          // we should exit recovery mode because the user object is new.
          _log.info("AuthStateChange: UserUpdated event WHILE in recovery mode. Exiting recovery.");
           if (mounted) {
            setState(() {
                _isInPasswordRecoveryMode = false;
                _initialStateProcessed = true;
            });
        }
      } else {
        _log.info("AuthStateChange: Other event (${data.event}), not changing recovery mode explicitly here unless already processed.");
        // If initial state is not yet processed, an auth event means we can process it now.
        if (mounted && !_initialStateProcessed) {
            setState(() {
                _initialStateProcessed = true;
            });
        }
      }
      _log.info("After AuthStateChange: _isInPasswordRecoveryMode: $_isInPasswordRecoveryMode, _initialStateProcessed: $_initialStateProcessed");
    });

    // Fallback to ensure UI doesn't hang if no link/auth events occur quickly
    // This timer will mark the initial state as processed if nothing else does it sooner.
    _initialStateTimer = Timer(const Duration(seconds: 3), () {
      _log.info("Initial state timer fired.");
      if (mounted && !_initialStateProcessed) {
        _log.warning("Initial state not processed by deep link or auth event within timeout, forcing processed state.");
        setState(() {
          _initialStateProcessed = true;
        });
      }
    });

    // Final check for current user if no events have fired yet to process state
    // This is for the case where app starts, user is logged in, no deep link.
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (mounted && !_initialStateProcessed && currentUser != null && !_isInPasswordRecoveryMode) {
        _log.info("initState: User already logged in and not in recovery, setting _initialStateProcessed = true");
        // Use addPostFrameCallback to avoid setState during build phase if initState is too fast
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_initialStateProcessed) {
                 setState(() {
                    _initialStateProcessed = true;
                });
            }
        });
    } else if (mounted && !_initialStateProcessed && currentUser == null && !_isInPasswordRecoveryMode) {
        _log.info("initState: No user and not in recovery, setting _initialStateProcessed = true");
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_initialStateProcessed) {
                 setState(() {
                    _initialStateProcessed = true;
                });
            }
        });
    }
    _log.info("End of initState. _isInPasswordRecoveryMode: $_isInPasswordRecoveryMode, _initialStateProcessed: $_initialStateProcessed");
  }

  Future<void> _initDeepLinks() async {
    _log.info("Initializing deep links listener...");
    _uriLinkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _log.info('Received deep link via stream: $uri');
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        _log.severe('Error listening to deep links: $err');
        if (mounted && !_initialStateProcessed) {
          setState(() {
            _initialStateProcessed = true; // Mark processed to avoid loading hang
            _log.warning("Deep link stream error, setting _initialStateProcessed = true to show UI.");
          });
        }
      },
      onDone: () {
        _log.info("Deep link stream done.");
        if (mounted && !_initialStateProcessed) {
            // If stream closes and we haven't processed, means no initial link via stream.
            // Auth events or timer should have caught it, but as a safeguard:
            setState(() {
                _initialStateProcessed = true;
                _log.info("Deep link stream done and not processed, setting _initialStateProcessed=true");
            });
        }
      }
    );
  }

  void _handleDeepLink(Uri uri) {
    _log.info("Handling deep link: $uri. Current mode: $_isInPasswordRecoveryMode, Processed: $_initialStateProcessed");
    _initialStateTimer?.cancel(); // Deep link received, cancel fallback timer

    if (uri.scheme == 'com.ahenyagan.eli5' &&
        uri.host == 'login-callback' &&
        uri.queryParameters['type'] == 'recovery') {
      _log.info("Password recovery deep link detected by _handleDeepLink.");

      if (mounted) {
        setState(() {
          _isInPasswordRecoveryMode = true;
          _initialStateProcessed = true; // Link processed, state known
        });
        _log.info("After handling recovery deep link: _isInPasswordRecoveryMode: $_isInPasswordRecoveryMode, _initialStateProcessed: $_initialStateProcessed");
      }
    } else {
      _log.info("Non-recovery deep link or unhandled link type. Path: ${uri.path}, Host: ${uri.host}, Query: ${uri.queryParameters}");
      if (mounted && !_initialStateProcessed) {
        setState(() {
          _initialStateProcessed = true; // Mark as processed to show main UI
        });
      }
    }
  }

  @override
  void dispose() {
    _log.info("AuthGate dispose");
    _authSubscription?.cancel();
    _uriLinkSubscription?.cancel();
    _initialStateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.info("AuthGate build. RecoveryMode: $_isInPasswordRecoveryMode, StateProcessed: $_initialStateProcessed");

    if (!_initialStateProcessed) {
      _log.info("Initial state not yet processed, showing loading indicator.");
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isInPasswordRecoveryMode) {
      _log.info("In password recovery mode, showing NewPasswordScreen.");
      return const NewPasswordScreen();
    }

    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    _log.info("User: ${user?.id}, Session: ${session?.accessToken != null ? 'exists' : 'null'}");

    if (user != null && session != null) {
      _log.info("User logged in, showing AppShell.");
      return const AppShell();
    } else {
      _log.info("User not logged in or no session, showing LoginScreen.");
      return const LoginScreen();
    }
  }
} 