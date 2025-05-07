# Progress

*   **Current Status:** Post-MVP development. Feature complete for Text, URL, YouTube Transcript, Q&A inputs, History, and initial Refactoring.
*   **What Works:**
    *   MVP features (Text simplification, basic UI, API key handling, copy, etc.).
    *   Generic URL content fetching and simplification.
    *   YouTube video transcript fetching and simplification.
    *   Question answering via OpenAI.
    *   History saving (limited size) using `shared_preferences`.
    *   History screen for viewing and clearing entries.
    *   Refactored core logic into `OpenAIService` and `ContentFetcherService`.
    *   SnackBar error notifications.
    *   **Chat Functionality MVP Complete:** Conversational chat with text, URL, and YouTube video processing.
    *   **Supabase Authentication Complete:** Login, Sign Up, Logout flow implemented with AuthGate.
    *   **Chat History Persistence MVP Complete:** Saving sessions/messages to Supabase, loading sessions via Drawer.
    *   **Chat History UX Refinement:** Added active session highlighting.
    *   **Chat History Management:** Added session deletion.
*   **What's Next / To Do:**
    *   **Implement Monetization (RevenueCat) - In Progress:**
        *   Google Play Console setup & verifications pending.
        *   RevenueCat dashboard configuration in progress.
        *   SDK added to Flutter project.
    *   Refine Chat History UX (e.g., delete option).
    *   Implement API Key Security (Proxy via Supabase Edge Function).
    *   UI Polish & UX Improvements.
    *   Advanced settings (e.g., choosing different GPT models, tone of simplification).
*   **What's Left:** Monetization, API Key Security (Proxy), advanced settings, UI polish & refinements, further refactoring.
*   **Known Issues:**
    *   Requires manual creation/update of `.env` file.
    *   Basic HTML parsing for generic URLs (might miss content or grab extra).
    *   YouTube transcript only works if captions are available.
    *   Windows build requires Developer Mode enabled. 