import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../models/user_profile.dart';

/// Service for Supabase authentication (including Google OAuth)
class SupabaseAuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Sign in with Google using Supabase OAuth
  static Future<UserProfile?> signInWithGoogle() async {
    try {
      debugPrint('SupabaseAuth: Starting Google OAuth...');

      // Use Supabase OAuth which opens a web view
      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.chesshare://login-callback/',
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );

      if (!result) {
        debugPrint('SupabaseAuth: OAuth launch failed');
        return null;
      }

      // Wait for the auth state to change
      final authState = await _client.auth.onAuthStateChange.firstWhere(
        (state) => state.event == AuthChangeEvent.signedIn,
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Sign in timeout');
        },
      );

      final user = authState.session?.user;
      if (user == null) {
        debugPrint('SupabaseAuth: No user after OAuth');
        return null;
      }

      debugPrint('SupabaseAuth: User signed in: ${user.id}');

      // Get or create profile
      final profile = await _getOrCreateProfile(user);
      await LocalDatabase.saveUserProfile(profile);

      return profile;
    } catch (e) {
      debugPrint('SupabaseAuth: Google sign in error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  static Future<UserProfile?> signInWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) return null;

      final profile = await _getOrCreateProfile(user);
      await LocalDatabase.saveUserProfile(profile);

      return profile;
    } catch (e) {
      debugPrint('SupabaseAuth: Email sign in error: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  static Future<UserProfile?> signUpWithEmail(String email, String password, String? fullName) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      final user = response.user;
      if (user == null) return null;

      final profile = await _getOrCreateProfile(user);
      await LocalDatabase.saveUserProfile(profile);

      return profile;
    } catch (e) {
      debugPrint('SupabaseAuth: Email sign up error: $e');
      rethrow;
    }
  }

  /// Get current user profile
  static Future<UserProfile?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Check local database
      return await LocalDatabase.getCurrentUserProfile();
    }

    return await _getOrCreateProfile(user);
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      // Keep local profile data for offline access
    } catch (e) {
      debugPrint('SupabaseAuth: Sign out error: $e');
    }
  }

  /// Check if user is signed in
  static bool get isSignedIn => _client.auth.currentUser != null;

  /// Get or create profile from Supabase user
  static Future<UserProfile> _getOrCreateProfile(User user) async {
    // Try to fetch from profiles table
    try {
      final response = await _client
          .from('profiles')
          .select('id, email, full_name, avatar_url, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserProfile(
          id: response['id'] as String,
          email: response['email'] as String?,
          fullName: response['full_name'] as String?,
          avatarUrl: response['avatar_url'] as String?,
          createdAt: DateTime.tryParse(response['created_at'] as String? ?? '') ?? DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('SupabaseAuth: Error fetching profile: $e');
    }

    // Create from user data
    return UserProfile(
      id: user.id,
      email: user.email,
      fullName: user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String? ??
          user.userMetadata?['picture'] as String?,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  /// Create a guest profile (no sign-in required)
  static Future<UserProfile> createGuestProfile() async {
    final guestId = 'guest_${const Uuid().v4()}';
    final profile = UserProfile(
      id: guestId,
      fullName: 'Guest',
      createdAt: DateTime.now(),
    );

    await LocalDatabase.saveUserProfile(profile);
    return profile;
  }
}
