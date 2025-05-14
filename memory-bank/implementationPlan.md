# ELI5 App Implementation Plan

## Phase 1: Basic UI & OpenAI Integration (Core Chat Logic)
- **Objective:** Create a basic chat interface and integrate OpenAI for text processing.
- **Key Components:**
    - Task: Setup Flutter project with Riverpod for state management.
        - Status: Done
    - Task: Create `ChatMessage` model.
        - Status: Done
    - Task: Create `ChatProvider` using `StateNotifierProvider`.
        - Status: Done
    - Task: Build `ChatScreen` UI with `ListView.builder` and `TextField`.
        - Status: Done
    - Task: Create `ChatMessageBubble` widget.
        - Status: Done
    - Task: Implement `OpenAIService` with `getChatResponse` method for conversational history.
        - Status: Done
    - Task: Integrate `OpenAIService` into `ChatProvider` to send messages and receive AI responses.
        - Status: Done
    - Task: Manage `ChatState` (loading/error states) in `ChatProvider`.
        - Status: Done

## Phase 2: Content Processing & URL Handling
- **Objective:** Enable the app to process URLs (general web pages, YouTube videos) and use the fetched content in the chat.
- **Key Components:**
    - Task: Implement `ContentFetcherService` for fetching and parsing web content.
        - Status: Done
    - Task: Integrate `ContentFetcherService` into `ChatProvider`.
        - Status: Done
    - Task: Modify `OpenAIService` to accept override content for summarization/explanation.
        - Status: Done
    - Task: Update `ChatProvider` to detect URLs, fetch content, and pass it to `OpenAIService`.
        - Status: Done

## Phase 3: User Authentication with Supabase
- **Objective:** Implement user sign-up, login, and session management using Supabase.
- **Key Components:**
    - Task: Add `supabase_flutter` package and initialize Supabase.
        - Status: Done
    - Task: Create `LoginScreen` and `SignUpScreen` UIs.
        - Status: Done
    - Task: Implement navigation between login and sign-up screens.
        - Status: Done
    - Task: Implement Supabase `signUp` and `signInWithPassword` logic.
        - Status: Done
    - Task: Implement error handling for authentication (e.g., Snackbars).
        - Status: Done
    - Task: Create `AuthGate` widget to manage auth state and navigate users.
        - Status: Done

## Phase 4: Android App Signing & Initial Release Setup
- **Objective:** Prepare the Android app for release by setting up signing.
- **Key Components:**
    - Task: Generate a release keystore (`upload-keystore.jks`).
        - Status: Done
    - Task: Create and configure `key.properties` for signing credentials.
        - Status: Done
    - Task: Add `key.properties` to `.gitignore`.
        - Status: Done
    - Task: Update `android/app/build.gradle.kts` for release signing.
        - Status: Done
    - Task: Build signed Android App Bundle (`app-release.aab`).
        - Status: Done
    - Task: Initial Google Play Console upload and addressing setup prerequisites.
        - Details: Encountered store listing requirements (description, countries, health declaration).
        - Status: In Progress / Postponed (will complete fully after core app features)

## Phase 5: Robust Chat Persistence (Supabase)
- **Objective:** Implement saving and loading of chat messages and sessions using Supabase.
- **Key Components:**
    - Task: Define/confirm `chat_sessions` and `chat_messages` table structures in Supabase.
        - Status: Done
    - Task: Implement logic in `ChatProvider` (or a new service) to save user messages and AI responses to `chat_messages`, linked to a `chat_session` and `user_id`.
        - Status: Done
    - Task: Implement logic to load chat history for the active/latest session when `ChatScreen` opens.
        - Status: Done
    - Task: Define and thoroughly test Supabase RLS policies for `chat_sessions` and `chat_messages`.
        - Status: Done (Verified)

## Phase 6: Photo-to-Text Simplification Feature
- **Objective:** Allow users to capture text via camera for simplification by OpenAI.
- **Key Components:**
    - Task: Research and select appropriate Flutter packages for camera access (e.g., `image_picker`, `camera`) and OCR (e.g., `google_mlkit_text_recognition`).
        - Status: Done (`image_picker`, `google_mlkit_text_recognition` chosen)
    - Task: Implement UI for initiating photo capture from `ChatScreen`.
        - Status: Done (`IconButton` in input bar)
    - Task: Implement image capture flow using the chosen package(s).
        - Status: Done
    - Task: Implement OCR processing to extract text from the captured image.
        - Status: Done
    - Task: Integrate extracted text into the existing `ChatProvider` -> `OpenAIService` pipeline for simplification.
        - Status: Done
    - Task: Handle platform-specific permissions for camera and gallery access.
        - Status: Done (Implicit via `image_picker`)
    - Task: Display OCR'd text or simplified text appropriately in the chat UI.
        - Status: Done

## Phase 7: UI/UX Enhancements & Core Chat Features
- **Objective:** Improve the chat interface, user experience, and add essential chat functionalities, including UI integration for the photo feature.
- **Key Components:**
    - Task: Enhance chat history display (e.g., timestamps, smooth loading).
        - Status: Done (Timestamps, `HistoryListScreen`, recent chats on `ChatScreen` empty state)
    - Task: Implement functionality to clear current chat / start a new session.
        - Status: Done (Middle icon '+' in `CurvedNavigationBar` within `AppShell`)
    - Task: Improve loading and error indicators for AI responses and data fetching.
        - Status: Done (SpinKit indicators)
    - Task: Refine text input field behavior.
        - Status: Done (Input bar repositioned in empty state, styling adjustments)
    - Task: Add `AppBar` to `ChatScreen` with navigation options.
        - Status: Obsolete (Replaced by `AppShell`/`CurvedNavigationBar` structure)
    - Task: Integrate UI elements for initiating photo capture and displaying results seamlessly within the chat flow.
        - Status: Done (`IconButton` in input bar)
    - Task: Refine Chat Screen UI and UX
        - Details: Implemented optimistic delete with UNDO for "Recent Chats" list (consistent with History screen). Fixed RenderFlex overflow in SessionTileWidget (dense mode). Improved AI chat bubble distinction with a new background color.
        - Status: Done

## Phase 8: User Settings & Basic Profile Management
- **Objective:** Provide users with basic account management options.
- **Key Components:**
    - Task: Create a simple Settings screen.
        - Status: Done
    - Task: Display logged-in user's email on the Settings screen.
        - Status: Done
    - Task: Implement a "Sign Out" button and logic on the Settings screen.
        - Status: Done
    - Task: Add Theme Switching capability.
        - Status: Removed (App is now dark-mode only)

## Phase 9: Testing & Refinement
- **Objective:** Ensure app stability and a good user experience through thorough testing, including the new photo feature and UI overhaul.
- **Key Components:**
    - Task: Conduct end-to-end testing of all user flows (sign-up, login, chat, URL processing, photo-to-text, sign-out, navigation).
        - Status: In Progress
    - Task: Specifically test the photo capture, OCR accuracy, and simplification flow with various image types and conditions.
        - Status: In Progress
    - Task: Test error handling for network issues, API failures, OCR failures, permission denials, etc.
        - Status: In Progress
    - Task: Perform testing on Android emulators and physical devices.
        - Status: In Progress
    - Task: Conduct Accessibility Review (Contrast, Theming)
        - Details: Reviewed key UI elements, fixed Session Tile subtitle contrast.
        - Status: Done (Initial Pass)
    - Task: Implement Multi-select in History List Screen
        - Details: Added state management, tile UI/interactions, contextual app bar, batch delete with Undo (fixed UI refresh issue), batch star/unstar functionality.
        - Status: Done
    - Task: Implement Two-pane Layout for wider screens
        - Status: To Do

## Phase 10: Monetization with RevenueCat (Post-Core Features & Deployment Readiness)
- **Objective:** Integrate RevenueCat for subscription management once core features are stable and the app is deployment-ready.
- **Key Components:**
    - Task: Plan subscription tiers and features.
        - Status: To Do
    - Task: Set up RevenueCat account and configure products/entitlements.
        - Status: To Do
    - Task: Integrate RevenueCat SDK into the Flutter app.
        - Status: To Do
    - Task: Implement UI for displaying subscription options.
        - Status: To Do
    - Task: Implement purchase flow and entitlement checking.
        - Status: To Do
    - Task: Connect RevenueCat with Supabase (e.g., webhook or custom claims) to sync subscription status with user profiles.
        - Status: To Do
    - Task: Secure features based on subscription status.
        - Status: To Do
    - Task: Monitor app performance, reviews, and feedback post-launch.
        - Status: To Do

## Phase 11: Deployment & Publishing (Google Play Store - Post-Core Features)
- **Objective:** Prepare and publish the app on the Google Play Store.
- **Key Components:**
    - Task: Finalize all Google Play Console requirements (store listing, graphics, content rating, privacy policy).
        - Status: In Progress
    - Task: Create and manage testing tracks (closed, open) on Play Console effectively.
        - Status: In Progress
    - Task: Promote builds through testing tracks to production.
        - Status: To Do
    - Task: Monitor app performance, reviews, and feedback post-launch.
        - Status: To Do 