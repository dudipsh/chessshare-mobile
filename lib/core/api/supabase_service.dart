import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _isReady = false;

  /// Check if Supabase is ready for queries
  static bool get isReady => _isReady;

  /// Mark Supabase as ready (call after initialization)
  static void markReady() {
    _isReady = true;
    debugPrint('SupabaseService: Marked as ready');
  }

  /// Get the Supabase client (throws if not ready)
  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('SupabaseService: Client not ready - $e');
      rethrow;
    }
  }

  /// Safely get the client, returns null if not ready
  static SupabaseClient? get safeClient {
    try {
      if (!_isReady) return null;
      return Supabase.instance.client;
    } catch (e) {
      return null;
    }
  }

  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  static Session? get currentSession {
    try {
      return client.auth.currentSession;
    } catch (e) {
      return null;
    }
  }

  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Wait until Supabase is ready (max 5 seconds)
  static Future<bool> waitUntilReady({Duration timeout = const Duration(seconds: 5)}) async {
    if (_isReady) return true;

    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (_isReady) return true;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('SupabaseService: Timeout waiting for ready state');
    return _isReady;
  }
}
