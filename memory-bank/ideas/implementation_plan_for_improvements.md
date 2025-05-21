# Implementation Plan for Selected Improvements

This document outlines the plan for implementing high-impact and feasible improvements identified in `improvement_ideas.md`.

## Phase 1: Enhancing Core Explanations & Basic Feedback

**Goal:** Improve user trust, manage expectations, and gather initial actionable feedback.

### 1.1. Transparency & Expectation Management (Core Engine)

*   **Task:** Add a non-intrusive disclaimer for AI-generated content.
    *   **Location:** Subtly at the bottom of chat responses or in an "About AI" section.
    *   **Wording Example:** "ELI5 Bot is AI-powered. Explanations are simplified and may not cover all nuances. Please verify critical information."
    *   **Implementation:** Add a small text widget in `ChatMessageBubble` or a global setting.
*   **Task:** Enhance AI prompt to manage expectations for highly complex topics.
    *   **Logic:** If an input is flagged (either by user or heuristically by length/density) as very complex, the system prompt can guide the AI to preface its explanation.
    *   **Prompt Snippet Idea (to add to `OpenAIService` system prompt):** "If the user's query seems exceptionally complex, you can start with something like: 'That's a big topic! Here's a super simple starting point to get you going...'"
    *   **Implementation:** Modify `systemPromptContent` in `lib/services/openai_service.dart`.

### 1.2. Basic Feedback Mechanisms (User Feedback Loop)

*   **Task:** Implement a simple "Thumbs Up / Thumbs Down" rating for each AI explanation.
    *   **UI:** Add two small icon buttons below each AI message bubble in `ChatMessageBubble`.
    *   **Data Storage:**
        *   Create a new Supabase table (e.g., `explanation_feedback`) with columns: `message_id` (FK to `chat_messages`), `user_id`, `rating` (e.g., 1 for up, -1 for down), `timestamp`.
        *   When a button is tapped, record the rating.
    *   **Implementation:**
        *   Modify `lib/widgets/chat_message_bubble.dart`.
        *   Add a method to `ChatDbService` to save the rating.
        *   Call this service method from the chat provider/screen.
*   **Task:** Implement a "Report Explanation" feature.
    *   **UI:** Add a small "flag" icon or a "Report" option (perhaps in a long-press menu) on AI message bubbles.
    *   **Reporting Dialog:** Tapping "Report" opens a simple dialog with predefined categories (e.g., "Inaccurate," "Confusing," "Offensive," "Other").
    *   **Data Storage:**
        *   Use the same `explanation_feedback` table, adding a `report_category` (text) and `report_comment` (text, optional) column.
        *   Or, create a separate `reported_explanations` table.
    *   **Implementation:**
        *   Modify `lib/widgets/chat_message_bubble.dart`.
        *   Create a new dialog widget.
        *   Add methods to `ChatDbService` and the chat provider.

## Phase 2: Improving Engagement & Content Accessibility

**Goal:** Make the app more interactive and its content more shareable.

### 2.1. Audio Narration for Explanations (Engaging User Experience)

*   **Task:** Implement Text-to-Speech (TTS) for AI explanations.
    *   **UI:** Add a "speaker" icon button to AI message bubbles. Tapping it reads the explanation aloud. A second tap could stop/pause.
    *   **Package:** Utilize a Flutter TTS package (e.g., `flutter_tts`).
    *   **State Management:** Manage TTS state (playing, stopped) likely within the `ChatMessageBubble` or its controller.
    *   **Implementation:**
        *   Add TTS package to `pubspec.yaml`.
        *   Initialize and use TTS service in `ChatMessageBubble` or a dedicated audio service.

### 2.2. Enhanced Content Sharing (Engaging User Experience)

*   **Task:** Explicit "Copy Text" Functionality.
    *   **UI:** Add a "copy" icon button to AI message bubbles or as an option in a long-press menu.
    *   **Implementation:** Use `Clipboard.setData(ClipboardData(text: messageText))` in `ChatMessageBubble`.
*   **Task:** Social Sharing of Explanations.
    *   **UI:** Add a "share" icon button to AI message bubbles.
    *   **Package:** Use the `share_plus` package.
    *   **Content to Share:** Share the explanation text. Consider adding a small attribution like "Explained by ELI5 App: [link_to_app_store]".
    *   **Implementation:** Integrate `share_plus` in `ChatMessageBubble`.

## Future Considerations (Post Phase 1 & 2)

*   **Gamified Feedback:** (e.g., highlighting parts of text).
*   **Visual Summaries / Related Concepts:** (Requires significant AI/Content work).
*   **Document Upload (PDF/Text):** (Requires file handling and backend processing).
*   **Systematic analysis of collected feedback** to iteratively refine AI prompts in `OpenAIService`.

This plan provides a structured approach. Each task will require further breakdown into sub-tasks during development.
