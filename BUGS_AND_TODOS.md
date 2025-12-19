# ChessShare - Bugs & Next Steps

## Current Status
- App runs without crashes
- Guest mode works (local storage)
- Google Sign-In disabled (needs configuration)
- Stockfish - debugging in progress

---

## BUGS

### 1. Stockfish Engine - Debugging
**Status:** IN PROGRESS
**Symptom:** Shows "No analysis yet" or "Starting engine..."

**Added Debug Logs:**
Run app and check console for:
- `Stockfish: Starting initialization...`
- `Stockfish: Instance created`
- `Stockfish output: ...` (UCI responses)
- `Stockfish: Initialization complete`

**Evaluation bar now shows:**
- "Starting engine..." - Engine initializing
- "Analyzing..." - Engine working
- "Engine error: ..." - Initialization failed
- "No analysis yet" - Engine ready but no analysis triggered

**Files with debug logs:**
- `services/stockfish_service.dart` - Full init logs
- `providers/engine_provider.dart` - State changes

### 2. Google Sign-In Not Configured
**Status:** Expected (needs setup)
**Symptom:** Only "Get Started" button shown, creates guest account

**To Enable:**
1. Create Google Cloud Console project
2. Enable Google Sign-In API
3. Create iOS OAuth Client ID
4. Add to `ios/Runner/Info.plist`:
```xml
<key>GIDClientID</key>
<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```
5. Run with: `--dart-define=GOOGLE_SIGN_IN_CONFIGURED=true`

---

## TODO - Priority Order

### HIGH Priority
- [ ] Fix Stockfish engine initialization
- [ ] Debug why analysis isn't running
- [ ] Add engine error display in UI

### MEDIUM Priority
- [ ] Configure Google Sign-In properly
- [ ] Add Apple Sign-In configuration
- [ ] Fix all `withOpacity` deprecation warnings

### LOW Priority
- [ ] Refactor more large files into components
- [ ] Add proper error handling throughout
- [ ] Add loading states for async operations

---

## Files Changed This Session

1. `lib/features/auth/services/google_auth_service.dart` - Safe initialization
2. `lib/features/auth/screens/login_screen.dart` - Guest mode primary
3. `lib/features/auth/providers/auth_provider.dart` - Better error handling
4. `lib/core/services/app_init_service.dart` - NEW centralized init
5. `lib/features/analysis/screens/analysis_screen.dart` - Eval bar fix
6. `lib/features/games/widgets/*` - Refactored from screen

---

## Quick Commands

```bash
# Run app
flutter run --dart-define=SUPABASE_URL=https://nobysgvvygfqzfsbellh.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vYnlzZ3Z2eWdmcXpmc2JlbGxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg5OTgwMzgsImV4cCI6MjA1NDU3NDAzOH0.GKAybR45O9_9GiX8TvK0pEBmO7jS7mG8lj_weKY5hY4

# Analyze code
flutter analyze lib/

# Clean build
flutter clean && flutter pub get
```
