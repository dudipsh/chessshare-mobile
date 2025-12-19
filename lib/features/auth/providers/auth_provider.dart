import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../models/user_profile.dart';
import '../services/google_auth_service.dart';

// Auth mode
enum AuthMode {
  online,  // Connected to Supabase
  offline, // Using local Google auth + SQLite
}

// Auth state (renamed to avoid conflict with Supabase's AuthState)
class AppAuthState {
  final supabase.User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;
  final AuthMode mode;
  final bool isGuest;

  AppAuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
    this.mode = AuthMode.offline,
    this.isGuest = false,
  });

  AppAuthState copyWith({
    supabase.User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
    AuthMode? mode,
    bool? isGuest,
    bool clearUser = false,
    bool clearProfile = false,
  }) {
    return AppAuthState(
      user: clearUser ? null : (user ?? this.user),
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      mode: mode ?? this.mode,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  bool get isAuthenticated => profile != null;
}

// Auth notifier
class AuthNotifier extends StateNotifier<AppAuthState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthNotifier() : super(AppAuthState(isLoading: true)) {
    _init();
  }

  void _init() async {
    // First, try to load from local database
    await _tryLoadLocalProfile();

    // Then, try online auth if available
    try {
      _authSubscription = SupabaseService.authStateChanges.listen((data) {
        final user = data.session?.user;
        if (user != null) {
          _loadProfile(user);
        }
      });

      // Check current session
      final user = SupabaseService.currentUser;
      if (user != null) {
        _loadProfile(user);
      }
    } catch (e) {
      // Supabase not available, continue with offline mode
      print('Supabase not available, using offline mode: $e');
    }
  }

  /// Try to load profile from local database first
  Future<void> _tryLoadLocalProfile() async {
    try {
      // Try silent Google sign-in first
      final profile = await GoogleAuthService.signInSilently();
      if (profile != null) {
        state = AppAuthState(
          profile: profile,
          mode: AuthMode.offline,
          isGuest: profile.id.startsWith('guest_'),
        );
        return;
      }

      // Check for cached profile
      final cachedProfile = await LocalDatabase.getCurrentUserProfile();
      if (cachedProfile != null) {
        state = AppAuthState(
          profile: cachedProfile,
          mode: AuthMode.offline,
          isGuest: cachedProfile.id.startsWith('guest_'),
        );
        return;
      }

      // No profile found
      state = AppAuthState();
    } catch (e) {
      print('Error loading local profile: $e');
      state = AppAuthState();
    }
  }

  Future<void> _loadProfile(supabase.User user) async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        state = AppAuthState(
          user: user,
          profile: UserProfile.fromJson(response),
        );
      } else {
        // Create profile if doesn't exist
        await _createProfile(user);
      }
    } catch (e) {
      state = AppAuthState(user: user, error: e.toString());
    }
  }

  Future<void> _createProfile(supabase.User user) async {
    try {
      final profile = {
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
        'avatar_url': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client.from('profiles').upsert(profile);

      state = AppAuthState(
        user: user,
        profile: UserProfile.fromJson(profile),
      );
    } catch (e) {
      state = AppAuthState(user: user, error: e.toString());
    }
  }

  /// Sign in with Google (native)
  Future<void> signInWithGoogle() async {
    // Check if Google Sign-In is available
    if (!GoogleAuthService.isAvailable) {
      state = state.copyWith(
        error: 'Google Sign-In is not configured for this device. Please use guest mode or contact support.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await GoogleAuthService.signIn();
      if (profile != null) {
        state = AppAuthState(
          profile: profile,
          mode: AuthMode.offline,
          isGuest: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in was cancelled',
        );
      }
    } catch (e) {
      String errorMessage = 'Sign-in failed';
      if (e.toString().contains('not configured')) {
        errorMessage = 'Google Sign-In is not configured. Please use guest mode.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'No internet connection. Please try again.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  /// Sign in with Google via Supabase OAuth (for online features)
  Future<void> signInWithGoogleOnline() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: 'com.chessshare.app://login-callback',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        supabase.OAuthProvider.apple,
        redirectTo: 'com.chessshare.app://login-callback',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Continue as guest (no sign-in required)
  Future<void> continueAsGuest() async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await GoogleAuthService.createGuestProfile();
      state = AppAuthState(
        profile: profile,
        mode: AuthMode.offline,
        isGuest: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await GoogleAuthService.signOut();
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      // Ignore errors during sign out
    }
    state = AppAuthState();
  }

  /// Delete account and all data
  Future<void> deleteAccount() async {
    try {
      await GoogleAuthService.disconnect();
    } catch (e) {
      // Ignore errors
    }
    state = AppAuthState();
  }

  Future<void> updateChessComUsername(String username) async {
    if (state.profile == null) return;

    try {
      // Update local database
      await LocalDatabase.updateUserProfile(
        state.profile!.id,
        {'chess_com_username': username},
      );

      // Update Supabase if online
      if (state.mode == AuthMode.online) {
        await SupabaseService.client
            .from('profiles')
            .update({'chess_com_username': username})
            .eq('id', state.profile!.id);
      }

      state = state.copyWith(
        profile: state.profile!.copyWith(chessComUsername: username),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateLichessUsername(String username) async {
    if (state.profile == null) return;

    try {
      // Update local database
      await LocalDatabase.updateUserProfile(
        state.profile!.id,
        {'lichess_username': username},
      );

      // Update Supabase if online
      if (state.mode == AuthMode.online) {
        await SupabaseService.client
            .from('profiles')
            .update({'lichess_username': username})
            .eq('id', state.profile!.id);
      }

      state = state.copyWith(
        profile: state.profile!.copyWith(lichessUsername: username),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier();
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final userProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).profile;
});
