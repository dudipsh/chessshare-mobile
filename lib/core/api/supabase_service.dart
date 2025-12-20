import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _isReady = false;
  static SupabaseClient? _publicClient;
  static SupabaseClient? _authClient;
  static bool _errorLoggedOnce = false;

  // Direct Supabase URL (bypasses custom domain issues)
  static const directUrl = 'https://xnczyeqqgkzlbqrplsdg.supabase.co';
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhuY3p5ZXFxZ2t6bGJxcnBsc2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0NzQ3NDYsImV4cCI6MjA1ODA1MDc0Nn0.pZZJ9QT-LKtzAM2d1K3-LqqKS18GrFlbhH62Bt9rL_k';

  /// Check if Supabase is ready for queries
  static bool get isReady => _isReady;

  /// Check if user is authenticated and Supabase is ready
  static bool get canMakeAuthenticatedCalls => _isReady && currentUser != null;

  /// Mark Supabase as ready (call after initialization)
  static void markReady() {
    _isReady = true;
    _errorLoggedOnce = false;
    debugPrint('SupabaseService: Marked as ready');
  }

  /// Log error only once to avoid spamming console
  static void _logErrorOnce(String message) {
    if (!_errorLoggedOnce) {
      debugPrint(message);
      _errorLoggedOnce = true;
    }
  }

  /// Get the Supabase client (throws if not ready)
  static SupabaseClient get client {
    if (!_isReady) {
      _logErrorOnce('SupabaseService: Client not ready - Supabase not initialized');
      throw StateError('Supabase not initialized');
    }
    try {
      return Supabase.instance.client;
    } catch (e) {
      _logErrorOnce('SupabaseService: Client error - $e');
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
  /// Now returns the main client since we use direct URL
  static SupabaseClient get authClient {
    // Use the main client - it's now configured with direct URL
    // This ensures the session is shared across all operations
    if (_isReady) {
      return Supabase.instance.client;
    }
    // Fallback to separate client if main not ready (shouldn't happen)
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

  /// Refresh the current session
  static Future<bool> refreshSession() async {
    try {
      if (!_isReady) return false;
      final response = await Supabase.instance.client.auth.refreshSession();
      debugPrint('SupabaseService: Session refreshed, new expiry: ${response.session?.expiresAt}');
      return response.session != null;
    } catch (e) {
      debugPrint('SupabaseService: Failed to refresh session: $e');
      return false;
    }
  }

  /// Check if session needs refresh (expires within given duration)
  static bool sessionNeedsRefresh({Duration threshold = const Duration(minutes: 5)}) {
    final session = currentSession;
    if (session == null) return false;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return expiryTime.isBefore(DateTime.now().add(threshold));
  }

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
