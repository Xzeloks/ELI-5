# Active Context

The primary focus has recently been on enhancing core application security and user experience through navigation improvements.

**Completed Tasks:**

1.  **API Key Security via Supabase Edge Function:**
    *   Successfully implemented a Supabase Edge Function (`openai-proxy`) to act as a secure intermediary for OpenAI API calls.
    *   The `OPENAI_API_KEY` is now stored as a Supabase secret, no longer exposed in the client application.
    *   Flutter's `OpenAIService` was refactored to communicate with this Edge Function using the `SUPABASE_ANON_KEY`.
    *   Deployment issues related to Docker permissions on Windows were resolved.

2.  **Back Button Navigation Overhaul:**
    *   Addressed issues where the system back button would prematurely exit the app.
    *   Implemented `WillPopScope` in `AppShell` to define a clear navigation flow for the main tabs (History, Chat, Settings), with Chat as the primary tab for exit confirmation.
    *   Refactored navigation for opening specific chat sessions from the history list. These now use `Navigator.push` to open a dedicated `ChatScreen` instance (with an `AppBar` and back button), ensuring users are returned to the history list upon pressing back.

**Current Status:**
These foundational improvements are now complete. The application is more secure and offers a more intuitive navigation experience.

**Next Focus:**

*   **Finalizing the UI for the Settings Page (`lib/screens/settings_screen.dart`):**
    *   Review existing elements and implement any necessary additions or refinements (e.g., links for support, legal information, app version).

The recent development cycle focused on significant UI polish and bug fixing across various screens, including the Chat Screen, History Screen, App Shell (Navbar), and Authentication Screen. This included implementing glow effects, resolving visual artifacts (like the separator line and TabBar indicator line), and iterating on theme colors.

**Key accomplishments in this phase:**
*   Finalized glow effects for chat input, chat bubbles, and session tiles.
*   Resolved visual artifacts related to shadows and dividers on the History and Auth screens.
*   Standardized the CurvedNavigationBar color and its integration.
*   Created a stable checkpoint for these UI refinements.
*   Successfully implemented API Key Security via Supabase Edge Function.
*   Overhauled back button navigation for a more intuitive user experience.

**Current Focus:**
*   **Feature Implementation (Phase 2):** Implementing Text-to-Speech (TTS) for AI explanations.
    *   **Status:** OpenAI TTS via Supabase Edge Function (`openai-tts-proxy`) is now functional both locally and deployed to Supabase Cloud. The Flutter app integrates with the deployed function.
*   **Next Immediate Task:** Begin implementation of "Enhanced Content Sharing" (Task 2.2 from `implementation_plan_for_improvements.md`), starting with "Copy Text" functionality.

**Next Steps (General):**
1.  Complete UI development for the Settings page.
2.  Once Settings page UI is finalized, the next major task will be the **Implementation of Monetization using RevenueCat**.
3.  Update `implementationPlan.md` as these tasks progress.
4.  Conduct thorough testing of new UI elements and the eventual monetization flow.

Monetization (RevenueCat) and full Play Console deployment will follow now that the core features, API security, navigation, and UI structure are refined.

**Recently Completed / Current Status (In-App Purchases & Paywall):**

*   **RevenueCat Integration & User Linking:**
    *   Successfully linked Supabase User IDs with RevenueCat App User IDs using `Purchases.logIn()` and `Purchases.logOut()`.
    *   Test purchases are now visible and correctly attributed in the RevenueCat sandbox environment.
*   **Paywall Logic & Navigation:**
    *   `AuthGate.dart` has been significantly refactored to manage user flow based on subscription status (checked via `customerInfoProvider` and the "Access" entitlement).
    *   Navigation from `PaywallScreen.dart` post-purchase is now handled by `AuthGate` reacting to updated `CustomerInfo`.
    *   `SettingsScreen.dart` dynamically shows "Manage Subscription" or "View Subscription Options" based on entitlement status.
*   **Console Log Review:**
    *   Reviewed RevenueCat debug logs, confirming successful operations and identifying areas for future attention (response verification for production, UI performance).

**Previous Work (Still Relevant Foundation):**
*   Deep Linking Implementation for Supabase email auth.
*   Paywall UI enhancements (currency formatting).
*   API Key Security via Supabase Edge Function.
*   Back Button Navigation Overhaul.
*   **Password Reset Flow Correction:** Refined `AuthGate` logic and `NewPasswordScreen` to ensure users are correctly redirected to the login screen after a successful password reset by explicitly signing them out post-update.

**Current Focus / Immediate Next Steps:**

1.  **Thorough Testing of In-App Purchase Flows (using Custom Paywall):**
    *   Confirm custom paywall (`PaywallScreen.dart`) is functioning correctly.
    *   **New User Purchase:** Sign up, go through custom paywall, purchase, verify access and UI changes.

**Update based on user confirmation:**
*   **Custom Paywall Functionality Confirmed:** The custom paywall (`PaywallScreen.dart`) is now confirmed to be working as intended. In-app purchase flows (new user purchase, access verification) have been successfully tested.

2.  **Monitor RevenueCat Dashboard (Sandbox):** Continue to observe customer data, transactions, and entitlement updates in RevenueCat during testing.
3.  **Address Minor Logged Items (Future):**
    *   Plan to enable RevenueCat "Response Verification" before production.
    *   Investigate and address Flutter performance warnings (skipped frames) for UI smoothness.
4.  **Continue Google Play Console Closed Testing:** Once IAP flows are stable, prepare and submit a new build incorporating these changes to the closed test track.

**Broader Goals (Post-IAP Testing):**
*   Proceed with iOS testing for RevenueCat.
*   Finalize any remaining UI polish.
*   Move towards wider testing and eventual production release.

**Paywall 'Try for Free' Troubleshooting & OpenAI Model Upgrades (Recent Focus):**

*   **'Try for Free' Issue (Ongoing):**
    *   Investigating why `StoreProduct.introductoryPrice` is consistently `null` for the monthly subscription package, preventing the "Try for Free" button from appearing as intended on the `PaywallScreen`.
    *   **Primary Hypothesis:** The Google account used for testing is not considered eligible by Google Play for the "new customer acquisition" free trial offer. Prior interactions (even test purchases) can affect this.
    *   **Key Troubleshooting Steps Undertaken:**
        *   Enhanced logging in `PaywallScreen.dart` to clearly show `introductoryPrice` details (or lack thereof) for each package.
        *   Confirmed the `purchases_flutter` (RevenueCat SDK) version is up-to-date (`^8.0.0`).
        *   Re-verified Google Play Console offer configuration for the `monthly` product (specifically the `freetrial` offer ensuring it's active, price is 0, and eligibility is for new customers).
        *   Reviewed RevenueCat's server-to-server notification setup (confirmed correct, though not directly for initial offer fetching).
        *   Clarified that `introductoryPrice` can refer to any special intro offer (free or discounted), and the app correctly checks for `price == 0` for the "Try for Free" logic.
    *   **Next Critical Step:** Rigorous testing using a "pristine" Google account (never used for Play Store purchases/subscriptions, especially with this app) on a clean device/emulator instance to definitively check offer eligibility.

*   **OpenAI Model Upgrade (Completed & Stable):**
    *   Upgraded models in `OpenAIService` to use `gpt-4o-mini` as the default and `gpt-4o` for potentially larger contexts/inputs.
    *   Adjusted associated token and character count limits for content processing and API calls.

**Chatbot Prompt Enhancements & Response Quality (Recent Focus):**

*   **Issue Addressed:** Generic chatbot responses to questions about app usage.
*   **Improvements:**
    *   Augmented the OpenAI system prompt in `lib/services/openai_service.dart` with specific details about the ELI5 app's features (text, URL, OCR, question input, style selection).
    *   Instructed the AI to use this information when asked for app usage examples.
    *   Guided the AI towards a more natural, conversational response style, discouraging excessive use of lists.
*   **Current Status:** Chatbot should now provide more relevant and varied responses regarding app functionality.

**Onboarding, Release Prep, and Paywall Implementation (Recent Major Focus):**

*   **Onboarding Enhancements:**
    *   Updated introductory text in `AppBreakdownScreen` to be more comprehensive, including mentioning YouTube link support.
*   **Release Preparation (v1.0.0+3):**
    *   Incremented app version in `pubspec.yaml`.
    *   Successfully generated an Android App Bundle (`.aab`) for release.
    *   Drafted release notes for Play Console submission.
*   **Custom Paywall Implementation (`PaywallScreen.dart` & `AuthGate.dart`):**
    *   **Decision:** Opted for a custom-built paywall UI (shown *after* onboarding) instead of RevenueCat's pre-built templates, using RevenueCat for backend purchase logic.
    *   **Navigation Flow in `AuthGate`:**
        *   Modified `AuthGate` to display `PaywallScreen` after the `AppBreakdownScreen` (onboarding) if the paywall hasn't been seen/acknowledged (`hasSeenPaywallKey` in SharedPreferences).
        *   `PaywallScreen` calls back to `AuthGate` to mark the paywall as seen and proceed to `AppShell`.
    *   **`PaywallScreen` Features & Logic:**
        *   Fetches offerings using `offeringsProvider` (RevenueCat SDK).
        *   Displays available subscription packages.
        *   Handles purchase attempts via `_purchasePackage`.
        *   Checks for "Access" entitlement in `customerInfo` post-purchase to grant app access.
        *   Includes a "Restore Purchases" functionality.
        *   Paywall is currently mandatory; "Maybe Later" option was removed.
    *   **RevenueCat Configuration:** Addressed initial offering fetch errors by ensuring correct product, entitlement ("Access"), and offering setup in the RevenueCat dashboard.
    *   **UI State:** Initial UI implemented. A more polished redesign was started but then deferred by user request to prioritize memory bank updates.

**Current Overall Status of Paywall/IAP:** The core functionality of the custom paywall, including fetching offerings, processing purchases, checking entitlements ('Access'), and restoring purchases, is implemented and confirmed to be working. The paywall is integrated into the post-onboarding flow.

**Previous Active Context (still relevant for broader goals but superseded by immediate tasks above):**
*   **Google Play Console - Production Readiness:**
    *   The immediate task is to address the requirements for applying for production access in the Google Play Console.
    *   This involves setting up a closed test track.
    *   Key requirements include:
        *   Publishing a closed test version.
        *   Ensuring at least 12 test users are registered for the closed test.
        *   Conducting closed testing with these users for at least 14 days.
*   ~~**Troubleshooting Data Isolation & Chat Loading:**~~ (RESOLVED)
    *   ~~Concurrently, investigating and resolving the issue where opening chat sessions from history results in a blank chat page. This might be related to RLS policies and how `user_id` was previously associated with messages, or a bug in the loading/display logic for historical chats.~~ 