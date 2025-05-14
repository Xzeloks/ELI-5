import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter/foundation.dart'; // REMOVED - Unnecessary
import 'dart:async'; // Added for Future
import 'dart:io'; // Import for Platform environment
// import '../models/history_entry.dart'; // REMOVED - Unused in main.dart
// import '../services/history_service.dart'; // REMOVED - Unused in main.dart
// import '../services/openai_service.dart';       // REMOVED - Unused in main.dart
// import '../services/content_fetcher_service.dart'; // REMOVED - Unused in main.dart
// import '../screens/history_screen.dart'; // REMOVED - Unused in main.dart
// import '../screens/auth/login_screen.dart'; // Removed unused import
// import 'package:youtube_explode_dart/youtube_explode_dart.dart'; // REMOVED - Unused in main.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_gate.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // Import RevenueCat Purchases
import 'package:google_fonts/google_fonts.dart';

// Define App Colors (keeping both, but only dark theme will be used)
class AppColors {
  static const Color kopyaPurple = Color(0xFF6200EE);
  static const Color primaryDarkPurple = Color(0xFF3700B3); // Darker shade of kopyaPurple
  static const Color brightBlue = Color(0xFF0487D9);
  static const Color darkTealBlue = Color(0xFF03588C);
  static const Color burntOrange = Color(0xFFD97F30);

  static const Color nearBlack = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color inputFillDark = Color(0xFF2A2A2A);

  static const Color textHighEmphasisDark = Color(0xFFFAFAFA);
  static const Color textMediumEmphasisDark = Color(0xFFBDBDBD);
  static const Color textDisabledDark = Color(0xFF757575);

  static const Color offWhite = Color(0xFFF5F5F5);
  static const Color whiteSurface = Colors.white;
  static const Color inputFillLight = Color(0xFFEFEFEF);

  static const Color textHighEmphasisLight = Color(0xFF121212);
  static const Color textMediumEmphasisLight = Color(0xFF424242);
  static const Color textDisabledLight = Color(0xFF9E9E9E);
  
  static const Color textOnPrimaryDark = Colors.white;
  static const Color textOnPrimaryLight = Colors.white;

  static const Color dividerDark = Color(0xFF303030);
  static const Color dividerLight = Color(0xFFE0E0E0);
}

// REMOVED themeModeProvider
// final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Provider for the Supabase auth user stream
final authUserStreamProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((authState) {
    return authState.session?.user;
  });
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env", mergeWith: Platform.environment);
  } catch (e) {
    // Handle error
    print('Error loading .env file: $e'); // Added print for error
  }
  await Supabase.initialize(
    url: 'https://dhztoureixsskctbpovk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoenRvdXJlaXhzc2tjdGJwb3ZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY1MzQ4MTgsImV4cCI6MjA2MjExMDgxOH0.n1R4Mwj2l0FICRtLG76J0Y8f_5DLhl4MaBuxePva5qE',
  );

  // Initialize RevenueCat
  // try {
  //   await Purchases.setLogLevel(LogLevel.debug); // Optional: for debugging
  //   // TODO: Replace with your actual RevenueCat API keys
  //   String revenueCatApiKey;
  //   if (Platform.isAndroid) {
  //     revenueCatApiKey = "goog_cDDinrdQJBPDaEiLIRWboxoywPd"; // Replace with your Google Play API key
  //   } else if (Platform.isIOS) {
  //     revenueCatApiKey = "YOUR_APP_STORE_API_KEY_HERE"; // Replace with your App Store API key
  //   } else {
  //     // Handle other platforms or throw an error if unsupported
  //     throw Exception("Unsupported platform for RevenueCat initialization");
  //   }
  //   await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  //   print('RevenueCat configured successfully.');
  // } catch (e) {
  //   print('Error configuring RevenueCat: $e');
  //   // Handle error appropriately, perhaps show a message to the user or disable paywall features
  // }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final themeMode = ref.watch(themeModeProvider); // REMOVED

    // Define Light ColorScheme - REMOVED
    // const lightColorScheme = ColorScheme.light(...);

    // Light Theme - REMOVED
    // final ThemeData lightTheme = ThemeData.from(colorScheme: lightColorScheme).copyWith(...);

    // Define Dark ColorScheme
    const darkColorScheme = ColorScheme.dark(
      primary: AppColors.kopyaPurple,
      secondary: AppColors.brightBlue,
      surface: AppColors.darkSurface,
      error: Colors.redAccent,
      onPrimary: AppColors.textOnPrimaryDark,
      onSecondary: AppColors.textOnPrimaryLight,
      onSurface: AppColors.textHighEmphasisDark,
      onError: Colors.white,
      brightness: Brightness.dark,
    );

    // Dark Theme (adjustments based on ColorScheme)
    final ThemeData darkTheme = ThemeData.from(colorScheme: darkColorScheme).copyWith(
       scaffoldBackgroundColor: AppColors.darkSurface,
       appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.surface, 
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.normal, color: AppColors.textHighEmphasisDark),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme.copyWith(
          titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textHighEmphasisDark), 
          titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: AppColors.textHighEmphasisDark),
          titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: AppColors.textHighEmphasisDark),
          bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5, color: AppColors.textMediumEmphasisDark),
          bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25, color: AppColors.textMediumEmphasisDark),
          labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25, color: AppColors.textHighEmphasisDark), 
          bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4, color: AppColors.textDisabledDark), 
        )
      ).apply(
        bodyColor: AppColors.textMediumEmphasisDark, 
        displayColor: AppColors.textHighEmphasisDark 
      ),
      iconTheme: IconThemeData(color: AppColors.textMediumEmphasisDark), 
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColorScheme.primary, 
          foregroundColor: darkColorScheme.onPrimary, 
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
          shape: const StadiumBorder(), 
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkColorScheme.primary, 
          side: BorderSide(color: darkColorScheme.primary), 
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
          shape: const StadiumBorder(), 
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.burntOrange, 
        foregroundColor: Colors.white,
      ),
      dividerColor: AppColors.dividerDark, 
      inputDecorationTheme: InputDecorationTheme( 
        filled: true,
        fillColor: AppColors.inputFillDark,
        hintStyle: GoogleFonts.poppins(color: AppColors.textDisabledDark, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: AppColors.textMediumEmphasisDark, fontSize: 16),
        floatingLabelStyle: GoogleFonts.poppins(color: AppColors.kopyaPurple, fontSize: 16), 
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), 
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), 
          borderSide: BorderSide(color: AppColors.dividerDark, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), 
          borderSide: BorderSide(color: AppColors.kopyaPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), 
          borderSide: BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), 
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      cardTheme: CardTheme( 
        elevation: 0, 
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: AppColors.dividerDark, width: 1.0), 
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0), 
      ),
    );

    return MaterialApp(
      title: 'ELI5 App',
      // theme: lightTheme, // REMOVED
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark, // Hardcoded to dark mode
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Removed Eli5Screen (old home page code)
