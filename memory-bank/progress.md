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
*   **What's Left:** Further features (e.g., advanced settings, UI polish), further refactoring.
*   **Known Issues:**
    *   Requires manual creation/update of `.env` file.
    *   Basic HTML parsing for generic URLs (might miss content or grab extra).
    *   YouTube transcript only works if captions are available.
    *   Windows build requires Developer Mode enabled. 