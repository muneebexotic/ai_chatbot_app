# Project Structure

## Root Directory
```
├── lib/                    # Main Dart source code
├── assets/                 # Static assets (images, fonts, icons)
├── android/               # Android-specific configuration
├── ios/                   # iOS-specific configuration
├── web/                   # Web-specific configuration
├── windows/               # Windows-specific configuration
├── macos/                 # macOS-specific configuration
├── linux/                 # Linux-specific configuration
├── test/                  # Unit and widget tests
├── pubspec.yaml           # Dependencies and project configuration
└── analysis_options.yaml  # Dart analyzer configuration
```

## lib/ Architecture (Feature-First + Layered)

### Core Configuration
- `lib/main.dart` - App entry point with provider setup
- `lib/config/` - App-wide configuration
  - `bootstrap.dart` - App initialization (Firebase, system UI)
  - `app_providers.dart` - Provider dependency injection setup
  - `app_router.dart` - Route configuration

### Feature Layers
- `lib/screens/` - UI screens (pages/views)
- `lib/widgets/` - Reusable UI components
- `lib/components/` - Complex UI components with business logic
- `lib/providers/` - State management (Provider pattern)
- `lib/controllers/` - Screen-specific business logic
- `lib/services/` - External API and platform integrations
- `lib/models/` - Data models and entities

### Supporting Code
- `lib/constants/` - App constants and static data
- `lib/utils/` - Helper functions and utilities
- `lib/mixins/` - Reusable behavior (mainly animations)

## Naming Conventions

### Files & Directories
- Use `snake_case` for all file and directory names
- Screen files: `*_screen.dart` (e.g., `chat_screen.dart`)
- Provider files: `*_provider.dart` (e.g., `auth_provider.dart`)
- Service files: `*_service.dart` (e.g., `gemini_service.dart`)
- Controller files: `*_controller.dart` (e.g., `login_controller.dart`)
- Model files: descriptive names (e.g., `chat_message.dart`, `app_user.dart`)

### Classes & Variables
- Use `PascalCase` for class names
- Use `camelCase` for variables, methods, and parameters
- Use `SCREAMING_SNAKE_CASE` for constants

## Architecture Patterns

### State Management
- **Provider Pattern**: Primary state management solution
- **ChangeNotifier**: For reactive state updates
- **Consumer/Selector**: For efficient UI rebuilds
- **ProxyProvider**: For dependent providers (e.g., auth-dependent services)

### Dependency Flow
```
main.dart → app_providers.dart → Individual Providers → Services → Models
```

### Screen Structure
Each screen typically follows this pattern:
1. **Screen Widget** (`lib/screens/`) - UI layout and navigation
2. **Controller** (`lib/controllers/`) - Business logic and state
3. **Provider** (`lib/providers/`) - Global state management
4. **Service** (`lib/services/`) - External integrations
5. **Models** (`lib/models/`) - Data structures

## Asset Organization
- `assets/images/` - App images and graphics
- `assets/fonts/` - Custom fonts (Poppins, Urbanist)
- `assets/png_icons/` - PNG icon assets
- `assets/logo.png` - Main app logo
- `assets/google_logo.png` - Google branding

## Key Architectural Decisions
- **Single Responsibility**: Each file has a clear, focused purpose
- **Separation of Concerns**: UI, business logic, and data access are separated
- **Provider Pattern**: Centralized state management with reactive updates
- **Service Layer**: External dependencies abstracted behind service interfaces
- **Feature Grouping**: Related functionality grouped together (e.g., auth, chat, subscription)