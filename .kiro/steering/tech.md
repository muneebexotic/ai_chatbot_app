# Technology Stack

## Framework & Language
- **Flutter**: Cross-platform UI framework (SDK ^3.8.1)
- **Dart**: Programming language

## Backend Services
- **Firebase Core**: Backend infrastructure
- **Firebase Auth**: User authentication with Google Sign-In
- **Cloud Firestore**: NoSQL database for chat history and user data
- **Firebase Storage**: File storage for images and media

## AI & ML Services
- **Google Generative AI**: Gemini API for chat conversations
- **OpenAI**: DALL-E for image generation
- **Hugging Face**: Alternative image generation models
- **Stability AI**: Stable Diffusion for image generation
- **Cloudinary**: Image processing and CDN

## Key Dependencies
- **Provider**: State management (^6.1.2)
- **HTTP**: API communication (^1.4.0)
- **Speech-to-Text**: Voice input (^7.1.0)
- **Flutter TTS**: Text-to-speech output (^4.2.3)
- **Image Picker**: Camera/gallery access (^1.1.2)
- **Shared Preferences**: Local storage (^2.5.3)
- **In-App Purchase**: Subscription management (^3.2.3)
- **Flutter Markdown**: Rich text rendering
- **Connectivity Plus**: Network status monitoring

## Development Tools
- **Flutter Launcher Icons**: App icon generation
- **Flutter Native Splash**: Splash screen configuration
- **Change App Package Name**: Package renaming utility

## Common Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Run with hot reload
flutter run --hot

# Build for specific platforms
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle
flutter build ios --release          # iOS
flutter build web --release          # Web
flutter build windows --release      # Windows
flutter build macos --release        # macOS
flutter build linux --release        # Linux
```

### Testing & Analysis
```bash
# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .

# Check for outdated packages
flutter pub outdated
```

### Asset Management
```bash
# Generate app icons
flutter pub run flutter_launcher_icons

# Generate native splash screens
flutter pub run flutter_native_splash:create
```

## Build Configuration
- **Minimum SDK**: Android API 21+, iOS 12+
- **Target SDK**: Latest stable versions
- **Signing**: Configured via android/key.properties
- **Obfuscation**: Enab