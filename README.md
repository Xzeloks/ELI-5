# ELI5: Explain Like I'm 5

An AI-powered mobile application (Flutter) that simplifies complex topics from various sources, making learning easier and more accessible.

## Core Features

-   **AI-Driven Explanations:** Get complex subjects broken down into simple, easy-to-understand explanations.
-   **Multiple Input Methods:**
    -   Direct text input.
    -   Text recognition from images (OCR) using Google ML Kit.
    -   Content extraction from YouTube video URLs via `youtube_explode_dart`.
-   **User Authentication & History:** Secure user accounts and a persistent history of your explained content, synced using Supabase.
-   **Subscription Model:** Access premium features through a subscription model managed by RevenueCat.

## Tech Stack

-   **Frontend:** Flutter
-   **Backend & Auth:** Supabase
-   **AI Service:** User-configurable (e.g., OpenAI). The application is set up to use an API key typically named `OPENAI_API_KEY`.
-   **In-App Purchases:** RevenueCat
-   **Text Recognition (OCR):** Google ML Kit
-   **Video Content Parsing:** `youtube_explode_dart`

## Project Structure Overview

-   `lib/`: Contains all the main Dart application code.
    -   `main.dart`: The entry point of the application, handling initialization of services.
    -   `models/`: Defines the data structures (classes) used throughout the app.
    -   `providers/`: Holds Riverpod state management providers for managing app state.
    -   `screens/`: Contains the UI for different pages/views of the app.
    -   `services/`: Includes logic for interacting with external APIs and backend services (Supabase, AI, etc.).
    -   `widgets/`: Houses reusable UI components used across multiple screens.
-   `supabase/`: Includes configuration files and any Edge Functions for the Supabase backend.
-   `assets/`: Stores static assets like app icons, images, and font files.
-   `ios/`, `android/`, `web/`, `macos/`, `linux/`, `windows/`: Platform-specific setup and configuration files for Flutter.

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

-   Flutter SDK: Ensure you have Flutter installed. For installation instructions, see the [official Flutter documentation](https://flutter.dev/docs/get-started/install).
-   An IDE: Android Studio or Visual Studio Code (with Flutter and Dart plugins).

### Clone

Clone the repository to your local machine:

```bash
git clone <repository-url>
```

### Environment Setup

1.  Create a `.env` file in the root directory of the project.
2.  Add the necessary API keys and configuration variables. This file is included in `.gitignore` and should not be committed to the repository.

    ```env
    SUPABASE_URL=YOUR_SUPABASE_URL
    SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
    OPENAI_API_KEY=YOUR_OPENAI_API_KEY
    REVENUECAT_GOOGLE_API_KEY=YOUR_REVENUECAT_GOOGLE_API_KEY
    REVENUECAT_APPLE_API_KEY=YOUR_REVENUECAT_APPLE_API_KEY
    ```

    *Note on AI Service:* The application is designed to integrate with an AI service for explanations. The `OPENAI_API_KEY` is provided as a common example; you will need to supply a valid key for the AI service you choose to use.

### Install Dependencies

Navigate to the project directory and run:

```bash
flutter pub get
```

### Run the Application

```bash
flutter run
```

Select your desired emulator/device when prompted.

## Contributing

Contributions are welcome! If you have suggestions for improvements or encounter any issues, please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details. (If a `LICENSE` file does not exist, this can be updated accordingly).
