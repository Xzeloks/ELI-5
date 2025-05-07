import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added for Riverpod
// import 'package:flutter/foundation.dart'; // REMOVED - Unnecessary
import 'dart:async'; // Added for Future
import 'dart:io'; // Import for Platform environment
import '../models/history_entry.dart'; // Import HistoryEntry model
import '../services/history_service.dart'; // Import HistoryService
import '../services/openai_service.dart';       // Import OpenAI Service
import '../services/content_fetcher_service.dart'; // Import Content Fetcher Service
import '../screens/history_screen.dart'; // Import HistoryScreen
// import '../screens/auth/login_screen.dart'; // Removed unused import
import 'package:youtube_explode_dart/youtube_explode_dart.dart'; // Needed for _yt
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../widgets/auth_gate.dart'; // Import AuthGate
import 'package:purchases_flutter/purchases_flutter.dart'; // Import RevenueCat Purchases

Future<void> main() async {
  // Ensure Flutter bindings are initialized before using plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  // Ensure you have a .env file in the root with OPENAI_API_KEY
  try {
    // Try merging with platform environment
    await dotenv.load(fileName: ".env", mergeWith: Platform.environment);
    // debugPrint('.env file loaded successfully.'); // REMOVED - Unnecessary
  } catch (e) {
    // debugPrint('Error loading .env file: $e'); // REMOVED - Unnecessary
    // Handle the error appropriately in a real app
    // Maybe show a message to the user or exit
  }

  // Initialize Supabase
  // IMPORTANT: Replace with your actual Supabase URL and Anon Key
  // Consider using flutter_dotenv for these as well for better security
  await Supabase.initialize(
    url: 'https://dhztoureixsskctbpovk.supabase.co', // Replace with your Supabase project URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoenRvdXJlaXhzc2tjdGJwb3ZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY1MzQ4MTgsImV4cCI6MjA2MjExMDgxOH0.n1R4Mwj2l0FICRtLG76J0Y8f_5DLhl4MaBuxePva5qE', // Replace with your Supabase anon key
  );

  // Initialize RevenueCat Purchases
  // IMPORTANT: Replace with your actual RevenueCat API keys from your RevenueCat dashboard
  // You get these after setting up your app (Apple & Google) in RevenueCat.
  // Consider using flutter_dotenv for these keys as well.
  PurchasesConfiguration configuration;
  if (Platform.isIOS) {
    configuration = PurchasesConfiguration("YOUR_REVENUECAT_APPLE_API_KEY"); // Placeholder
  } else if (Platform.isAndroid) {
    configuration = PurchasesConfiguration("YOUR_REVENUECAT_GOOGLE_API_KEY"); // Placeholder
  } else {
    // Fallback or error for unsupported platforms if necessary
    // For now, let's assume we might need a generic key or handle error
    // This part might need adjustment based on how RevenueCat handles other platforms or if you only target mobile.
    configuration = PurchasesConfiguration("YOUR_REVENUECAT_FALLBACK_API_KEY_IF_ANY"); // Placeholder
  }
  await Purchases.configure(configuration);
  // Optional: Set up a listener for purchaser info updates
  // Purchases.addPurchaserInfoUpdateListener((purchaserInfo) { 
  //   // handle purchaser info updates 
  // });

  runApp(const ProviderScope(child: MyApp())); // Wrapped MyApp with ProviderScope
}

// Supabase client instance (can be accessed globally or via Riverpod provider)
// final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ELI5 Tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AuthGate(), // Changed to AuthGate
    );
  }
}

// Renamed MyHomePage to Eli5Screen and made it stateful
class Eli5Screen extends StatefulWidget {
  const Eli5Screen({super.key});

  @override
  State<Eli5Screen> createState() => _Eli5ScreenState();
}

class _Eli5ScreenState extends State<Eli5Screen> {
  // Controller for the input text field
  final _textController = TextEditingController();
  final _yt = YoutubeExplode(); // Instantiate YoutubeExplode
  final _historyService = HistoryService(); // Instantiate HistoryService
  final _openAIService = OpenAIService();
  final _contentFetcherService = ContentFetcherService();

  // State variables (will add more later)
  String _originalText = '';
  String _simplifiedText = '';
  bool _isLoading = false;

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _textController.dispose();
    _yt.close(); // Close the YoutubeExplode client
    _contentFetcherService.dispose(); // Dispose the content fetcher service
    super.dispose();
  }

  Future<void> _simplifyText() async {
    final inputText = _textController.text.trim();
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    String textToSimplify = inputText;
    String originalContent = inputText;

    // Determine input type using ContentFetcherService
    bool isQuestion = inputText.endsWith('?');
    bool isVideoUrl = _contentFetcherService.isYouTubeUrl(inputText);
    bool isGenericUrl = !isQuestion && !isVideoUrl && _contentFetcherService.isValidUrl(inputText);

    // Basic Input Validation
    if (inputText.isEmpty) {
      _showErrorSnackBar('Please enter text, URL, or question');
      return;
    }

    // API Key Validation
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
       _showErrorSnackBar('API Key not found or invalid. Check .env file.');
       return;
     }

    // Set loading state and clear previous results
    setState(() {
      _isLoading = true;
      _originalText = originalContent;
      _simplifiedText = '';
     });

    try {
      InputType currentInputType;
      // --- Step 1: Fetch content if it's a URL ---
      if (isVideoUrl) {
        currentInputType = InputType.video;
        // debugPrint("Fetching transcript from YouTube URL: $inputText");
        textToSimplify = await _contentFetcherService.fetchYouTubeTranscript(inputText);
        // debugPrint("YouTube transcript fetched successfully.");
      } else if (isGenericUrl) {
        currentInputType = InputType.url;
        // debugPrint("Fetching content from generic URL: $inputText");
        textToSimplify = await _contentFetcherService.fetchAndParseUrl(inputText);
        // debugPrint("Generic URL content fetched successfully.");
      } else if (isQuestion) {
         currentInputType = InputType.question;
         // No fetching needed, textToSimplify is already inputText
      } else {
         currentInputType = InputType.text;
         // No fetching needed, textToSimplify is already inputText
      }

      // --- Step 2: Call the API function using OpenAIService ---
      // debugPrint("Sending request to OpenAI...");
      final result = await _openAIService.fetchSimplifiedText(
          textToSimplify,
          apiKey,
          isQuestion: isQuestion
      );

      // --- Step 3: Save to History using HistoryService ---
      final newEntry = HistoryEntry(
          originalInput: originalContent,
          simplifiedOutput: result,
          timestamp: DateTime.now(),
          inputType: currentInputType,
      );
      await _historyService.addHistoryEntry(newEntry);
      // debugPrint("Entry saved to history.");

      // Update UI
      if (mounted) {
          setState(() {
            _simplifiedText = result;
            _isLoading = false;
          });
      }
      // debugPrint("Simplification successful.");

    } catch (e) {
      // Handle errors from any step
      if (mounted) {
        setState(() {
          _isLoading = false;
          _simplifiedText = '';
        });
        _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
      // debugPrint("Error during simplification process: $e");
    }
  }

  // Function to copy text to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // Show a confirmation message (optional)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ELI5 Text Simplifier'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: _viewHistory, // Add history button
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Input Text Field
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Enter text, URL, or question', // Updated label
                hintText: 'Paste complex text, a URL, or ask a question...', // Updated hint
                border: OutlineInputBorder(),
              ),
              maxLines: 5, // Allow multiple lines
            ),
            const SizedBox(height: 16.0), // Spacing

            // Simplify Button
            ElevatedButton(
              onPressed: _isLoading ? null : _simplifyText, // Disable button when loading
              child: const Text('Simplify'),
            ),
            const SizedBox(height: 24.0), // Spacing

            // Loading Indicator
            Visibility(
              visible: _isLoading,
              child: const Center(child: CircularProgressIndicator()),
            ),

            // Use Expanded and SingleChildScrollView to handle potentially long content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Original Text Display Area
                    Visibility(
                      visible: _originalText.isNotEmpty && !_isLoading,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Original Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8.0),
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: SelectableText(_originalText),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Simplified Text Display Area
                    Visibility(
                      visible: _simplifiedText.isNotEmpty && !_isLoading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Simplified Text (ELI5):', style: TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copyToClipboard(_simplifiedText),
                                tooltip: 'Copy Simplified Text',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: SelectableText(_simplifiedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder function for viewing history
  void _viewHistory() {
    // debugPrint("Navigating to History Screen...");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  // Helper function to show error SnackBar
  void _showErrorSnackBar(String message) {
    // Ensure the context is available and the widget is mounted
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating, // Optional: makes it float above bottom nav bar if any
      ),
    );
  }
}
