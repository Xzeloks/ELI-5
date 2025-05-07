# MVP Implementation Plan

This plan outlines the steps to build the Minimum Viable Product (MVP) focused on text simplification.

**Phase 1: Project Setup**
1.  **Create Flutter Project:** Initialize a new Flutter project named `eli5` using the `flutter create eli5` command.
2.  **Add Dependencies:** Add necessary packages to `pubspec.yaml`:
    *   `http`: For making HTTP requests to the OpenAI API.
    *   `flutter_dotenv`: For securely managing the OpenAI API key.
    *   Run `flutter pub get`.
3.  **API Key Setup:**
    *   Create a `.env` file in the project root.
    *   Add `OPENAI_API_KEY=YOUR_API_KEY_HERE` to the `.env` file.
    *   Add `.env` to the `.gitignore` file.
    *   Load the environment variables in `main.dart`.

**Phase 2: UI Development (`lib/main.dart` initially)**
1.  **Basic Structure:** Create a `StatefulWidget` for the main screen.
2.  **Input Field:** Add a multi-line `TextField` for user input, controlled by a `TextEditingController`.
3.  **Simplify Button:** Add an `ElevatedButton` labeled "Simplify".
4.  **Output Areas:** Add two `Container` widgets with `SelectableText` (or `Text` initially) to display the original input and the simplified output.
5.  **Copy Button:** Add an `IconButton` or `TextButton` next to the simplified output area.
6.  **Loading Indicator:** Add a `CircularProgressIndicator` that is conditionally displayed.
7.  **Error Display:** Add a `Text` widget to display error messages conditionally.

**Phase 3: Core Logic & API Integration**
1.  **State Variables:** In the `State` class, manage:
    *   Input text (`TextEditingController`).
    *   Original text for display (`String`).
    *   Simplified text output (`String`).
    *   Loading status (`bool`).
    *   Error message (`String?`).
2.  **API Service:** Create a separate Dart function (e.g., `fetchSimplifiedText(String inputText, String apiKey)`) that:
    *   Takes the input text and API key as arguments.
    *   Constructs the JSON payload for the OpenAI API (using `gpt-3.5-turbo` and an ELI5 prompt).
    *   Makes a POST request using the `http` package.
    *   Parses the response to extract the simplified text.
    *   Includes basic error handling (try-catch) for network or API errors.
    *   Returns the simplified text or throws an error.
3.  **Button Action:** Implement the `onPressed` handler for the "Simplify" button:
    *   Set loading state to `true`.
    *   Clear previous output and errors.
    *   Get text from the `TextEditingController`.
    *   Store the original text for display.
    *   Call the `fetchSimplifiedText` function.
    *   On success: Update the simplified text state.
    *   On error: Update the error message state.
    *   Set loading state to `false`.
4.  **Copy Functionality:** Implement the `onPressed` handler for the "Copy" button using `Clipboard.setData`.

**Phase 4: Refinement**
1.  **UI Polish:** Basic layout improvements (padding, spacing).
2.  **Error Handling:** Display errors more user-friendly (e.g., using `SnackBar`).

**Phase 5: Chat Functionality**
1.  **Chat UI:**
    *   Design a chat interface (e.g., using `ListView.builder` for messages, `TextField` for input).
    *   Display user messages and AI responses clearly.
2.  **State Management for Chat:**
    *   Choose a state management solution (e.g., Provider, Riverpod, BLoC) to manage the list of chat messages.
    *   Each message should store its content, sender (user/AI), and timestamp.
3.  **OpenAI API for Chat:**
    *   Modify `OpenAIService` to accept a list of previous messages (conversation history).
    *   Pass the conversation history to the OpenAI API to maintain context.
    *   The prompt for simplification/Q&A should now consider the ongoing conversation.
4.  **Integrating Chat with Simplification:**
    *   When a user asks for simplification or asks a question, it becomes part of a chat session.
    *   The simplified text or answer is displayed as an AI response in the chat.

**Phase 6: User Authentication (Supabase)**
1.  **Choose Authentication Provider:**
    *   Decision: **Supabase Auth**.
    *   Integrate using the `supabase_flutter` package.
2.  **Project Setup for Auth:**
    *   Set up a Supabase project.
    *   Add `supabase_flutter` to `pubspec.yaml`.
    *   Initialize Supabase in the Flutter app with project URL and anon key.
    *   Configure desired authentication methods in the Supabase dashboard (e.g., email/password, social logins).
3.  **Auth UI:**
    *   Create screens for Login and Sign Up.
    *   Implement forms for email/password or buttons for social logins using Supabase client methods.
4.  **Auth Logic:**
    *   Implement functions to handle user registration (`supabase.auth.signUp`), login (`supabase.auth.signInWithPassword`), and logout (`supabase.auth.signOut`).
    *   Manage user session using `supabase.auth.onAuthStateChange`.
    *   Secure app features based on authentication state.
5.  **User Data Storage (Supabase Database - PostgreSQL):**
    *   Create tables in Supabase database for:
        *   `user_profiles` (linked to `auth.users`, for any additional profile data if needed).
        *   `chat_sessions` (e.g., `id`, `user_id`, `created_at`, `title`).
        *   `chat_messages` (e.g., `id`, `session_id`, `sender` (user/ai), `content`, `timestamp`).
    *   Implement Row Level Security (RLS) policies in Supabase to ensure users can only access their own data.
    *   Store user's chat history and questions asked within these tables.

**Phase 7: Monetization (RevenueCat & Supabase)**
1.  **Subscription Management:**
    *   Integrate **RevenueCat** SDK for managing in-app purchases and subscriptions.
    *   Configure products/offerings in RevenueCat and app stores.
    *   Use RevenueCat webhooks or Supabase Edge Functions to sync subscription status with your Supabase user data (e.g., add a `subscription_active` field to `user_profiles`).
    *   Restrict features based on subscription tiers/status.

**Phase 8: API Key Security & Backend Proxy (Future Enhancement)**
1.  **Problem:** Client-side OpenAI API key is less secure.
2.  **Solution:**
    *   Create a simple backend proxy (e.g., using Supabase Edge Functions, Cloudflare Workers, or a dedicated server).
    *   Authenticated users make requests to your proxy.
    *   The proxy, holding the OpenAI API key securely, forwards requests to OpenAI and returns the response.
    *   This protects the API key and allows for better rate limiting and logging.
    *   This can be implemented after initial chat and auth features are stable.

**Phase 9: Refinement & Further Features**
1.  **UI/UX Polish:** Continuous improvements based on user feedback.
2.  **Advanced Settings:** Model selection, tone adjustment, etc.
3.  **Testing:** Unit, widget, and integration tests. 