# Chess Mastery

Premium Chess Analysis & Training App built with Flutter.

## Getting Started

### Prerequisites

- Flutter 3.16+
- Dart 3.0+
- Xcode (for iOS)
- Android Studio (for Android)

### Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Supabase credentials in `lib/main.dart` or use environment variables:
   ```bash
   flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app/                      # App configuration
│   ├── app.dart              # MaterialApp setup
│   ├── router.dart           # Navigation routes
│   └── theme/                # Design system
│       ├── app_theme.dart
│       └── colors.dart
├── core/                     # Core functionality
│   ├── chess/                # Chess board, logic, sounds
│   ├── api/                  # Supabase & external APIs
│   ├── database/             # Local SQLite database
│   └── utils/                # Utilities
├── features/                 # Feature modules
│   ├── auth/                 # Authentication
│   ├── games/                # Games list & import
│   ├── analysis/             # Game analysis
│   ├── study/                # Study boards
│   ├── puzzles/              # Mistake practice
│   ├── insights/             # Analytics dashboard
│   ├── profile/              # User profile
│   └── subscription/         # Premium subscriptions
└── shared/                   # Shared widgets & animations
```

## Documentation

See the `docs/` folder for detailed documentation:

- [Technical Specification](docs/TECHNICAL_SPEC.md) - API reference & architecture
- [PRD (English)](docs/PRD.md) - Product requirements
- [PRD (Hebrew)](docs/PRD_HE.md) - מסמך דרישות מוצר

## Backend

This app connects to the same Supabase backend as Chess Share web app.

## License

Proprietary - All rights reserved.
