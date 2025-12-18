import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/supabase_service.dart';
import '../models/user_profile.dart';

// Auth state (renamed to avoid conflict with Supabase's AuthState)
class AppAuthState {
  final supabase.User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  AppAuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AppAuthState copyWith({
    supabase.User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AppAuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null;
}

// Auth notifier
class AuthNotifier extends StateNotifier<AppAuthState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthNotifier() : super(AppAuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    // Listen to auth changes
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _loadProfile(user);
      } else {
        state = AppAuthState();
      }
    });

    // Check current session
    final user = SupabaseService.currentUser;
    if (user != null) {
      _loadProfile(user);
    } else {
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

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: 'com.chessmastery.app://login-callback',
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
        redirectTo: 'com.chessmastery.app://login-callback',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
    state = AppAuthState();
  }

  Future<void> updateChessComUsername(String username) async {
    if (state.profile == null) return;

    try {
      await SupabaseService.client
          .from('profiles')
          .update({'chess_com_username': username})
          .eq('id', state.profile!.id);

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
      await SupabaseService.client
          .from('profiles')
          .update({'lichess_username': username})
          .eq('id', state.profile!.id);

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
