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