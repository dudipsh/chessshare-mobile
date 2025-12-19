import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _isReady = false;
  static SupabaseClient? _publicClient;
  static SupabaseClient? _authClient;

  // Direct Supabase URL (bypasses custom domain issues)
  static const directUrl = 'https://xnczyeqqgkzlbqrplsdg.supabase.co';
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhuY3p5ZXFxZ2t6bGJxcnBsc2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0NzQ3NDYsImV4cCI6MjA1ODA1MDc0Nn0.pZZJ9QT-LKtzAM2d1K3-LqqKS18GrFlbhH62Bt9rL_k';

  /// Check if Supabase is ready for queries
  static bool get isReady => _isReady;

  /// Mark Supabase as ready (call after initialization)
  static void markReady() {
    _isReady = true;
    debugPrint('SupabaseService: Marked as ready');
  }

  /// Get the Supabase client (throws if not ready)
  /// This client uses the custom domain (for auth)
  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('SupabaseService: Client not ready - $e');
      rethrow;
    }
  }

  /// Get a client for public/anonymous queries
  /// Uses direct Supabase URL (bypasses custom domain issues)
  static SupabaseClient get publicClient {
    _publicClient ??= SupabaseClient(directUrl, anonKey);
    return _publicClient!;
  }

  /// Get a client specifically for auth operations
  /// Uses direct Supabase URL (required for signInWithIdToken)
  static SupabaseClient get authClient {
    _authClient ??= SupabaseClient(directUrl, anonKey);
    return _authClient!;
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
