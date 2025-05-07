import 'package:eli5/providers/chat_provider.dart';
import 'package:eli5/widgets/chat_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:eli5/widgets/chat_sessions_drawer.dart'; // Import the drawer

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      // AuthGate will handle navigation to LoginScreen automatically
      // No explicit navigation needed here if AuthGate is set up correctly.
      // However, good to show a small feedback if desired.
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully logged out.')),
        );
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
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isAiResponding = chatState.isAiResponding;
    // final errorMessage = chatState.errorMessage; // For displaying general errors if needed

    final TextEditingController messageController = TextEditingController();

    void sendMessage() {
      if (messageController.text.isNotEmpty) {
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
          // Show an error message in the chat or as a SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API Key not found or invalid. Check .env file.')),
          );
          // Optionally add an error message to the chat provider state
          // ref.read(chatProvider.notifier).addMessage('API Key not configured.', ChatMessageSender.ai);
          return;
        }
        ref.read(chatProvider.notifier).sendMessageAndGetResponse(messageController.text, apiKey);
        messageController.clear();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ELI5 Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Chat',
            onPressed: () {
              ref.read(chatProvider.notifier).startNewChatSession();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _signOut(context), 
          ),
        ],
      ),
      drawer: const ChatSessionsDrawer(), // Add the drawer here
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return ChatMessageBubble(message: message);
              },
            ),
          ),
          if (isAiResponding)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)),
                  SizedBox(width: 8),
                  Text("ELI5 Bot is thinking..."),
                ],
              ),
            ),
          // Optional: Display general error messages from chatState.errorMessage
          // if (errorMessage != null && !isAiResponding) ...
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: !isAiResponding, // Disable input while AI is responding
                    decoration: const InputDecoration(
                      hintText: 'Ask something or type text to simplify...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: isAiResponding ? null : (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: isAiResponding ? null : sendMessage, // Disable button while AI is responding
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 