# Project Structure

## Architecture Pattern
This Flutter app follows a **Provider-based MVVM architecture** with clear separation of concerns:

- **Models**: Data structures and business entities
- **Views**: UI screens and widgets
- **Providers**: State management and business logic
- **Services**: External API integrations and data persistence
- **Controllers**: Screen-specific logic and lifecycle management

## Folder Organization

### `/lib` - Main Application Code
```
lib/
├── main.dart                    # App entry point
├── components/                  # Reusable UI components
│   ├── ui/                     # Generic UI components
│   └── welcome/                # Welcome screen components
├── config/                     # App configuration
│   ├── app_providers.dart      # Provider setup
│   ├── app_router.dart         # Route definitions
│   └── bootstrap.dart          # App initialization
├── constants/                  # App constants and static data
├── controllers/                # Screen controllers (lifecycle management)
├── mixins/                     # Animation and behavior mixins
├── models/                     # Data models and entities
├── providers/                  # State management (Provider pattern)
├── screens/                    # Full-screen UI pages
├── services/                   # External integrations and APIs
├── utils/                      # Helper functions and utilities
└── widgets/                    # Custom reusable widgets
```

### Key Directories

#### `/models`
Data structures for:
- `app_user.dart` - User profile data
- `chat_message.dart` - Chat message structure
- `conversation.dart` - Chat conversation data
- `generated_image.dart` - AI-generated image metadata
- `image_generation_request.dart` - Image generation parameters

#### `/providers`
State management for:
- `auth_provider.dart` - Authentication state
- `chat_provider.dart` - Chat functionality
- `conversation_provider.dart` - Conversation management
- `image_generation_provider.dart` - Image generation state
- `subscription_provider.dart` - Premium features
- `themes_provider.dart` - UI theme management

#### `/services`
External integrations:
- `firestore_service.dart` - Database operations
- `gemini_service.dart` - AI chat API
- `image_generation_service.dart` - Image AI APIs
- `speech_service.dart` - Voice input/output
- `cloudinary_service.dart` - Image storage/processing

#### `/screens`
Main UI pages:
- `chat_screen.dart` - Primary chat interface
- `welcome_screen.dart` - Onboarding
- `login_screen.dart` / `signup_screen.dart` - Authentication
- `settings_screen.dart` - User preferences
- `subscription_screen.dart` - Premium features

## Naming Conventions

### Files & Directories
- Use `snake_case` for all file and directory names
- Suffix files with their type: `_screen.dart`, `_provider.dart`, `_service.dart`
- Group related files in appropriate directories

### Classes & Variables
- Use `PascalCase` for class names
- Use `camelCase` for variables and methods
- Use `SCREAMING_SNAKE_CASE` for constants
- Prefix private members with underscore `_`

### Assets
- Store in `/assets` with organized subdirectories
- Use descriptive names: `bot_icon.png`, `user_avatar.png`
- Include multiple resolutions for images when needed

## Configuration Files

### Root Level
- `pubspec.yaml` - Dependencies and app metadata
- `analysis_options.yaml` - Dart analyzer configuration
- `.env` - Environment variables (not committed)

### Platform Specific
- `/android` - Android build configuration
- `/ios` - iOS build configuration  
- `/web` - Web deployment files
- `/windows`, `/macos`, `/linux` - Desktop configurations

## Development Guidelines

### State Management
- Use Provider pattern for app-wide state
- Keep providers focused on single responsibilities
- Use `ChangeNotifier` for reactive state updates
- Implement proper disposal in providers

### Service Layer
- Keep services stateless and focused
- Implement proper error handling and timeouts
- Use dependency injection through providers
- Cache frequently accessed data appropriately

### UI Components
- Create reusable widgets in `/widgets`
- Use consistent theming through `AppTheme`
- Implement responsive design for multiple screen sizes
- Follow Material Design guidelines