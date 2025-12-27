# Chess Mastery - Build & Release Commands

## Development

```bash
# Run in debug mode
flutter run

# Run on specific device
flutter devices
flutter run -d <device_id>

# Hot restart
r (in terminal while running)

# Analyze code
flutter analyze
```

## Android Build

```bash
# Build APK (debug)
flutter build apk --debug

# Build APK (release)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Build App Bundle (for Google Play) - use Gradle directly on Apple Silicon
cd android && ./gradlew bundleRelease && cd ..
# Output: build/app/outputs/bundle/release/app-release.aab

# Alternative (may fail on Apple Silicon due to NDK strip issue):
# flutter build appbundle --release
```

## iOS Build

```bash
# Build iOS (debug)
flutter build ios --debug

# Build iOS (release)
flutter build ios --release

# Open in Xcode
open ios/Runner.xcworkspace
```

## Signing (Android)

### Keystore Location
- `android/upload-keystore.jks`
- `android/key.properties`

### Generate New Keystore (if needed)
```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### View Keystore Info
```bash
keytool -list -v -keystore android/upload-keystore.jks
```

## Clean & Reset

```bash
# Clean build files
flutter clean

# Get dependencies
flutter pub get

# Full reset
flutter clean && flutter pub get

# Clean iOS pods
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
```

## Testing

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/path/to/test.dart

# Run with coverage
flutter test --coverage
```

## Dependencies

```bash
# Update dependencies
flutter pub upgrade

# Check outdated packages
flutter pub outdated

# Add package
flutter pub add <package_name>
```

## Useful Debug Commands

```bash
# Check Flutter installation
flutter doctor

# List connected devices
flutter devices

# Get app logs
flutter logs

# Attach to running app
flutter attach
```

## Google Play Upload

1. Build: `flutter build appbundle --release`
2. File location: `build/app/outputs/bundle/release/app-release.aab`
3. Upload to: https://play.google.com/console

## App Store Upload

1. Build: `flutter build ios --release`
2. Open: `open ios/Runner.xcworkspace`
3. In Xcode: Product → Archive → Distribute App

## Version Update

Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # version_name+version_code
```
