# Developer Onboarding Guide - BlinkBasket

Welcome to the BlinkBasket engineering team! Follow this guide to set up your local development workspace.

---

## 1. Development Prerequisites
Ensure you have the following installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel, version 3.7.0 or higher).
*   [Android Studio](https://developer.android.com/studio) (for Android Emulator and SDK platforms).
*   [VS Code](https://code.visualstudio.com/) (recommended IDE with Flutter and Dart extensions).

---

## 2. Environment Setup

1.  **Clone the Repository:**
    ```bash
    git clone <repository_url>
    cd hypermart
    ```

2.  **Restore Packages:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Connection:**
    *   Ensure the whitelisted `firebase_options.dart` exists in `lib/`.
    *   Verify connectivity to your local development Firestore instance.

4.  **Run the App:**
    *   Open an emulator (Android/iOS).
    *   Launch with:
        ```bash
        flutter run
        ```

---

## 3. Coding Guidelines & Standards
*   **Clean Architecture:** Always place business rules in `domain/`, network mappings in `data/`, and layouts/providers in `presentation/` or `core/providers/`.
*   **Zero Compile Warnings:** Ensure all files analyze cleanly before committing. Run `flutter analyze` locally to audit your changes.
