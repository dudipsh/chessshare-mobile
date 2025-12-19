import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../models/user_profile.dart';

/// Service for Google Sign-In authentication
class GoogleAuthService {
  static GoogleSignIn? _googleSignIn;
  static bool _isInitialized = false;
  static bool _isConfigured = false;
  static String? _initError;

  /// Initialize Google Sign-In
  /// Only creates the GoogleSignIn object if native configuration is detected
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Google Sign-In is properly configured on this platform
      _isConfigured = await _checkNativeConfiguration();

      if (!_isConfigured) {
        _initError = 'Google Sign-In is not configured for this platform';
        debugPrint('Google Sign-In not configured - skipping initialization');
        _isInitialized = true;
        return;
      }

      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      _isInitialized = true;
      debugPrint('Google Sign-In initialized successfully');
    } catch (e) {
      _initError = e.toString();
      _isConfigured = false;
      debugPrint('Failed to initialize Google Sign-In: $e');
      _isInitialized = true;
    }
  }

  /// Check if native Google Sign-In configuration exists
  static Future<bool> _checkNativeConfiguration() async {
    try {
      if (Platform.isIOS) {
        // On iOS, check if the app has Google Sign-In configured
        // by checking for the GIDClientID in Info.plist via a method channel
        // For now, we'll use a safe default - assume not configured unless proven otherwise
        // This prevents crashes on unconfigured apps

        // Try to read the Info.plist to check for GIDClientID
        // Since we can't easily do this from Dart, we'll check using a test approach
        // that won't crash the app
        return await _testGoogleSignInConfigured();
      } else if (Platform.isAndroid) {
        // On Android, configuration is in google-services.json
        // The plugin will fail gracefully if not configured
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking native configuration: $e');
      return false;
    }
  }

  /// Test if Google Sign-In is configured without crashing
  static Future<bool> _testGoogleSignInConfigured() async {
    // For iOS, we need to check if GIDClientID exists in Info.plist
    // Since we can't directly read Info.plist from Dart without crashing,
    // we'll rely on a build-time flag or environment variable

    // Check for a build-time flag indicating Google Sign-In is configured
    const googleConfigured = bool.fromEnvironment(
      'GOOGLE_SIGN_IN_CONFIGURED',
      defaultValue: false,
    );

    if (googleConfigured) {
      debugPrint('Google Sign-In marked as configured via build flag');
      return true;
    }

    // Default to not configured to prevent crashes
    debugPrint('Google Sign-In not marked as configured - defaulting to disabled');
    return false;
  }

  /// Check if Google Sign-In is available and properly configured
  static bool get isAvailable => _isInitialized && _isConfigured && _googleSignIn != null;

  /// Get initialization error if any
  static String? get initializationError => _initError;

  /// Current signed in Google user
  static GoogleSignInAccount? get currentUser => _googleSignIn?.currentUser;

  /// Check if user is signed in
  static bool get isSignedIn => _googleSignIn?.currentUser != null;

  /// Sign in with Google
  static Future<UserProfile?> signIn() async {
    if (!isAvailable) {
      debugPrint('Google Sign-In not available: $_initError');
      throw Exception('Google Sign-In is not configured. Please use guest mode.');
    }

    try {
      // Try silent sign in first
      GoogleSignInAccount? account = await _googleSignIn!.signInSilently();
      account ??= await _googleSignIn!.signIn();

      if (account == null) return null;

      // Get or create user profile
      final profile = await _getOrCreateProfile(account);

      // Save to local database
      await LocalDatabase.saveUserProfile(profile);

      return profile;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Sign in silently (for returning users)
  static Future<UserProfile?> signInSilently() async {
    if (!isAvailable) {
      // Return cached profile if available
      return await LocalDatabase.getCurrentUserProfile();
    }

    try {
      final account = await _googleSignIn!.signInSilently();
      if (account == null) {
        // Check if we have a cached profile
        return await LocalDatabase.getCurrentUserProfile();
      }

      final profile = await _getOrCreateProfile(account);
      await LocalDatabase.saveUserProfile(profile);
      return profile;
    } catch (e) {
      // Return cached profile if available
      return await LocalDatabase.getCurrentUserProfile();
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
  }

  /// Disconnect (revoke access)
  static Future<void> disconnect() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.disconnect();
      }
      await LocalDatabase.clearAllData();
    } catch (e) {
      debugPrint('Google disconnect error: $e');
    }
  }

  /// Get or create user profile from Google account
  static Future<UserProfile> _getOrCreateProfile(GoogleSignInAccount account) async {
    // Check if profile exists in local database
    String id = account.id;
    UserProfile? existingProfile = await LocalDatabase.getUserProfile(id);

    if (existingProfile != null) {
      // Update with latest Google info
      final updatedProfile = existingProfile.copyWith(
        fullName: account.displayName,
        avatarUrl: account.photoUrl,
      );
      return updatedProfile;
    }

    // Create new profile
    return UserProfile(
      id: id,
      email: account.email,
      fullName: account.displayName,
      avatarUrl: account.photoUrl,
      createdAt: DateTime.now(),
    );
  }

  /// Generate a unique ID for guest users
  static String generateGuestId() {
    return 'guest_${const Uuid().v4()}';
  }

  /// Create a guest profile (no sign-in required)
  static Future<UserProfile> createGuestProfile() async {
    final guestId = generateGuestId();
    final profile = UserProfile(
      id: guestId,
      fullName: 'Guest',
      createdAt: DateTime.now(),
    );

    await LocalDatabase.saveUserProfile(profile);
    return profile;
  }
}
