# Technology Stack

## Framework & Language
- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language (SDK ^3.8.1)

## Backend Services
- **Firebase Core**: Backend infrastructure
- **Firebase Auth**: User authentication
- **Cloud Firestore**: NoSQL database for chat history
- **Firebase Storage**: File and image storage
- **Google Generative AI**: Gemini API for chat functionality

## Key Dependencies
- **State Management**: Provider pattern (provider ^6.1.2)
- **HTTP Client**: http ^1.4.0 for API calls
- **Voice Features**: 
  - speech_to_text ^7.1.0
  - flutter_tts ^4.2.3
- **Image Handling**:
  - image_picker ^1.1.2
  - cloudinary_api ^1.1.1 for image processing
- **UI/UX**:
  - flutter_svg ^2.2.0
  - flutter_markdown ^0.7.7+1
  - markdown_widget ^2.3.2+8
- **Payments**: in_app_purchase ^3.2.3
- **Storage**: shared_preferences ^2.5.3

## Build System
- **Flutter SDK**: Standard Flutter build system
- **Gradle**: Android builds (build.gradle, build.gradle.kts)
- **Xcode**: iOS builds
- **Native Splash**: flutter_native_splash for app launch

## Common Commands
```bash
# Development
flutter run                    # Run in debug mode
flutter run --release         # Run in release mode
flutter hot-reload            # Hot reload during development

# Building
flutter build apk             # Build Android APK
flutter build appbundle      # Build Android App Bundle
flutter build ios            # Build iOS app
flutter build web            # Build web version

# Testing & Analysis
flutter test                  # Run unit tests
flutter analyze              # Static code analysis
flutter doctor               # Check Flutter installation

# Dependencies
flutter pub get              # Install dependencies
flutter pub upgrade          # Update dependencies
flutter pub deps             # Show dependency tree

# Platform-specific
flutter build windows        # Build Windows app
flutter build macos          # Build macOS app
flutter build linux          # Build Linux app
```

## Code Quality
- **Linting**: flutter_lints ^6.0.0 with standard Flutter rules
- **Analysis**: analysis_options.yaml configured for Flutter best practices