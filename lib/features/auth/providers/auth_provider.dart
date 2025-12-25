import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../../games/services/games_cache_service.dart';
import '../../profile/services/profile_cache_service.dart';
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
    debugPrint('Auth: Starting initialization...');

    // Keep isLoading true until ALL auth checks complete
    UserProfile? localProfile;
    UserProfile? finalProfile;
    AuthMode finalMode = AuthMode.offline;

    // Step 1: Try to load cached profile first
    try {
      localProfile = await GoogleAuthService.signInSilently();
      localProfile ??= await LocalDatabase.getCurrentUserProfile();
      if (localProfile != null) {
        debugPrint('Auth: Found local profile: ${localProfile.id}');
      }
    } catch (e) {
      debugPrint('Auth: Error loading local profile: $e');
    }

    // Step 2: Try online auth if available
    bool supabaseAuthComplete = false;
    try {
      // Try to recover existing session first
      await _tryRecoverSession();

      // Set up auth state listener for future changes
      _authSubscription = SupabaseService.authStateChanges.listen((data) {
        final event = data.event;
        final user = data.session?.user;

        debugPrint('Auth state change: $event, user: ${user?.id}');

        if (event == supabase.AuthChangeEvent.signedIn && user != null) {
          _loadProfile(user);
        } else if (event == supabase.AuthChangeEvent.signedOut) {
          // User signed out, clear state but keep local profile for offline access
          state = state.copyWith(clearUser: true, mode: AuthMode.offline, isLoading: false);
        } else if (event == supabase.AuthChangeEvent.tokenRefreshed && user != null) {
          // Token was refreshed, update user
          debugPrint('Token refreshed for user: ${user.id}');
          state = state.copyWith(user: user);
        }
      });

      // Check current session after recovery
      final user = SupabaseService.currentUser;
      if (user != null) {
        debugPrint('Auth: Found Supabase user, loading profile...');
        // Load profile but don't update state yet - we'll do it at the end
        try {
          final response = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (response != null) {
            var profile = UserProfile.fromJson(response);
            profile = await _loadLinkedChessAccounts(user.id, profile);
            finalProfile = profile;
            finalMode = AuthMode.online;
            supabaseAuthComplete = true;
            debugPrint('Auth: Supabase profile loaded successfully');
          }
        } catch (e) {
          debugPrint('Auth: Error loading Supabase profile: $e');
        }
      }
    } catch (e) {
      // Supabase not available, continue with offline mode
      debugPrint('Supabase not available, using offline mode: $e');
    }

    // Step 3: Determine final state and set isLoading: false ONCE
    if (supabaseAuthComplete && finalProfile != null) {
      // Use Supabase profile
      state = AppAuthState(
        user: SupabaseService.currentUser,
        profile: finalProfile,
        mode: finalMode,
        isGuest: false,
        isLoading: false,
      );
    } else if (localProfile != null) {
      // Fall back to local profile
      debugPrint('Auth: Using local profile');
      state = AppAuthState(
        profile: localProfile,
        mode: AuthMode.offline,
        isGuest: localProfile.id.startsWith('guest_'),
        isLoading: false,
      );
    } else {
      // No profile found, user needs to log in
      debugPrint('Auth: No profile found, user needs to log in');
      state = AppAuthState(isLoading: false);
    }

    debugPrint('Auth: Initialization complete. isAuthenticated=${state.isAuthenticated}');
  }

  /// Try to recover session from stored tokens
  Future<void> _tryRecoverSession() async {
    try {
      if (!SupabaseService.isReady) {
        debugPrint('Session recovery: Supabase not ready');
        return;
      }

      // Get the current session - this will automatically try to refresh if expired
      final session = SupabaseService.currentSession;
      if (session != null) {
        debugPrint('Session recovery: Found existing session, expires at ${session.expiresAt}');

        // Check if session is expired or about to expire (within 60 seconds)
        final expiresAt = session.expiresAt;
        if (expiresAt != null) {
          final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          final now = DateTime.now();

          if (expiryTime.isBefore(now.add(const Duration(seconds: 60)))) {
            debugPrint('Session recovery: Session expired or expiring soon, refreshing...');
            await SupabaseService.client.auth.refreshSession();
            debugPrint('Session recovery: Session refreshed successfully');
          }
        }
      } else {
        debugPrint('Session recovery: No existing session found');
        // Try to re-authenticate using stored Google credentials
        await _tryReauthenticateWithGoogle();
      }
    } catch (e) {
      debugPrint('Session recovery error: $e');
      // Don't throw - session recovery failure is not fatal
    }
  }

  /// Try to re-authenticate with Supabase using stored Google credentials
  Future<void> _tryReauthenticateWithGoogle() async {
    try {
      debugPrint('Re-auth: Trying to get Google credentials silently...');

      // Try to get Google account silently (user already signed in before)
      final googleUser = await GoogleAuthService.getCredentialsSilently();
      if (googleUser == null) {
        debugPrint('Re-auth: No Google credentials available');
        return;
      }

      debugPrint('Re-auth: Got Google user ${googleUser.email}');

      // Get tokens
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        debugPrint('Re-auth: No ID token available');
        return;
      }

      debugPrint('Re-auth: Re-authenticating with Supabase...');

      // Sign in to Supabase with Google token
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        debugPrint('Re-auth: Success! User=${response.user!.id}');
        // The auth state listener will handle updating the profile
      } else {
        debugPrint('Re-auth: Failed - no user returned');
      }
    } catch (e) {
      debugPrint('Re-auth error: $e');
      // Don't throw - re-auth failure is not fatal, we'll continue in offline mode
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
        var profile = UserProfile.fromJson(response);

        // Load linked chess accounts from the server
        profile = await _loadLinkedChessAccounts(user.id, profile);

        state = AppAuthState(
          user: user,
          profile: profile,
          mode: AuthMode.online,
          isLoading: false,
        );
      } else {
        // Create profile if doesn't exist
        await _createProfile(user);
      }
    } catch (e) {
      debugPrint('Auth: Error loading profile: $e');
      state = AppAuthState(user: user, error: e.toString(), isLoading: false);
    }
  }

  /// Load linked chess accounts from Supabase and update the profile
  Future<UserProfile> _loadLinkedChessAccounts(String userId, UserProfile profile) async {
    try {
      // Get linked accounts from the linked_chess_accounts table via RPC
      final response = await SupabaseService.client.rpc('get_linked_chess_accounts');

      if (response != null && response is List && response.isNotEmpty) {
        String? chessComUsername = profile.chessComUsername;
        String? lichessUsername = profile.lichessUsername;

        for (final account in response) {
          final platform = account['platform'] as String?;
          final username = account['username'] as String?;
          if (platform == 'chesscom' && username != null) {
            chessComUsername = username;
          } else if (platform == 'lichess' && username != null) {
            lichessUsername = username;
          }
        }

        debugPrint('Loaded linked accounts from RPC: Chess.com=$chessComUsername, Lichess=$lichessUsername');

        // Update local database with the linked usernames
        if (chessComUsername != null || lichessUsername != null) {
          await LocalDatabase.updateUserProfile(userId, {
            if (chessComUsername != null) 'chess_com_username': chessComUsername,
            if (lichessUsername != null) 'lichess_username': lichessUsername,
          });
        }

        return profile.copyWith(
          chessComUsername: chessComUsername,
          lichessUsername: lichessUsername,
        );
      }
    } catch (e) {
      debugPrint('Error loading linked accounts: $e');
    }

    debugPrint('Using linked accounts from profile: Chess.com=${profile.chessComUsername}, Lichess=${profile.lichessUsername}');
    return profile;
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
        mode: AuthMode.online,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Auth: Error creating profile: $e');
      state = AppAuthState(user: user, error: e.toString(), isLoading: false);
    }
  }

  /// Sign in with Google using native sign-in + Supabase token
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      debugPrint('Google Sign-In: Starting...');

      // Use native Google Sign-In
      final googleUser = await GoogleAuthService.signInForToken();

      if (googleUser == null) {
        debugPrint('Google Sign-In: User cancelled');
        state = state.copyWith(isLoading: false, error: 'Sign-in was cancelled');
        return;
      }

      debugPrint('Google Sign-In: Got user ${googleUser.email}');

      // Get ID token
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      debugPrint('Google Sign-In: idToken=${idToken != null ? "present" : "NULL"}, accessToken=${accessToken != null ? "present" : "NULL"}');

      if (idToken == null) {
        state = state.copyWith(isLoading: false, error: 'No ID token - check serverClientId config');
        return;
      }

      debugPrint('Google Sign-In: Signing in to Supabase...');

      // Sign in to Supabase with Google token using direct URL (not custom domain)
      // The custom domain may not properly proxy auth requests
      final response = await SupabaseService.authClient.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('Google Sign-In: Supabase response user=${response.user?.id}');

      if (response.user != null) {
        // Since authClient returns Supabase.instance.client when ready,
        // the session is already on the main client - no sync needed
        debugPrint('Google Sign-In: Success! User=${response.user!.id}');
        if (response.session != null) {
          debugPrint('Google Sign-In: Session expires=${response.session!.expiresAt}');
        }
        await _loadProfile(response.user!);
      } else {
        state = state.copyWith(isLoading: false, error: 'Supabase returned no user');
      }
    } catch (e) {
      debugPrint('Google Sign-In ERROR: $e');
      String errorMessage = e.toString();
      if (errorMessage.length > 100) {
        errorMessage = errorMessage.substring(0, 100);
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await SupabaseService.client.auth.signInWithOAuth(
        supabase.OAuthProvider.apple,
        redirectTo: 'com.chessshare.app://login-callback',
        authScreenLaunchMode: supabase.LaunchMode.inAppWebView,
      );

      if (!result) {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign-in was cancelled',
        );
      }
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
      // Clear all caches before signing out
      await Future.wait([
        GamesCacheService.clearCache(),
        ProfileCacheService.clearCache(),
        _clearDailyPuzzleCache(),
      ]);
      debugPrint('Auth: Cleared all caches');

      await GoogleAuthService.signOut();
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      debugPrint('Auth: Error during sign out: $e');
    }
    state = AppAuthState();
  }

  /// Clear daily puzzle cached data
  Future<void> _clearDailyPuzzleCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('daily_puzzle_last_solved');
      await prefs.remove('daily_puzzle_streak');
      await prefs.remove('daily_puzzle_solved_dates');
      debugPrint('Auth: Cleared daily puzzle cache');
    } catch (e) {
      debugPrint('Auth: Error clearing daily puzzle cache: $e');
    }
  }

  /// Delete account and all data
  Future<void> deleteAccount() async {
    try {
      // Clear all caches
      await Future.wait([
        GamesCacheService.clearCache(),
        ProfileCacheService.clearCache(),
        _clearDailyPuzzleCache(),
      ]);
      await GoogleAuthService.disconnect();
    } catch (e) {
      debugPrint('Auth: Error during account deletion: $e');
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

      // Save to linked_chess_accounts table via RPC (the correct table)
      if (state.user != null) {
        await _saveLinkedChessAccount('chesscom', username);
      }

      state = state.copyWith(
        profile: state.profile!.copyWith(chessComUsername: username),
      );
    } catch (e) {
      debugPrint('Error updating Chess.com username: $e');
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

      // Save to linked_chess_accounts table via RPC (the correct table)
      if (state.user != null) {
        await _saveLinkedChessAccount('lichess', username);
      }

      state = state.copyWith(
        profile: state.profile!.copyWith(lichessUsername: username),
      );
    } catch (e) {
      debugPrint('Error updating Lichess username: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Save linked chess account to Supabase using RPC function
  Future<void> _saveLinkedChessAccount(String platform, String username) async {
    try {
      await SupabaseService.client.rpc('upsert_linked_chess_account', params: {
        'p_platform': platform,
        'p_username': username,
        'p_linked_at': DateTime.now().toUtc().toIso8601String(),
        'p_avatar_url': null,
      });
      debugPrint('Saved linked $platform account: $username');
    } catch (e) {
      // Log but don't throw - this is a secondary operation
      debugPrint('Failed to save linked chess account: $e');
    }
  }

  /// Delete linked chess account from Supabase
  Future<void> _deleteLinkedChessAccount(String platform) async {
    try {
      await SupabaseService.client
          .from('linked_chess_accounts')
          .delete()
          .eq('platform', platform);
      debugPrint('Deleted linked $platform account');
    } catch (e) {
      debugPrint('Failed to delete linked chess account: $e');
    }
  }

  /// Unlink Chess.com account
  Future<void> unlinkChessComAccount() async {
    if (state.profile == null) return;

    try {
      // Update local database
      await LocalDatabase.updateUserProfile(
        state.profile!.id,
        {'chess_com_username': null},
      );

      // Delete from linked_chess_accounts table
      if (state.user != null) {
        await _deleteLinkedChessAccount('chesscom');
      }

      state = state.copyWith(
        profile: state.profile!.copyWith(chessComUsername: null, clearChessComUsername: true),
      );
    } catch (e) {
      debugPrint('Error unlinking Chess.com account: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Unlink Lichess account
  Future<void> unlinkLichessAccount() async {
    if (state.profile == null) return;

    try {
      // Update local database
      await LocalDatabase.updateUserProfile(
        state.profile!.id,
        {'lichess_username': null},
      );

      // Delete from linked_chess_accounts table
      if (state.user != null) {
        await _deleteLinkedChessAccount('lichess');
      }

      state = state.copyWith(
        profile: state.profile!.copyWith(lichessUsername: null, clearLichessUsername: true),
      );
    } catch (e) {
      debugPrint('Error unlinking Lichess account: $e');
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
