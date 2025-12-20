import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/supabase_service.dart';

/// Result wrapper for repository calls
class RepoResult<T> {
  final T? data;
  final String? error;
  final bool success;

  const RepoResult._({this.data, this.error, required this.success});

  factory RepoResult.success(T data) => RepoResult._(data: data, success: true);
  factory RepoResult.failure(String error) => RepoResult._(error: error, success: false);
  factory RepoResult.empty() => const RepoResult._(success: true);
}

/// Base repository with centralized error handling and guards
abstract class BaseRepository {
  /// Track logged errors to avoid spam
  static final Set<String> _loggedErrors = {};
  static DateTime? _lastErrorClear;

  /// Clear old logged errors every 5 minutes
  static void _clearOldErrors() {
    final now = DateTime.now();
    if (_lastErrorClear == null || now.difference(_lastErrorClear!).inMinutes > 5) {
      _loggedErrors.clear();
      _lastErrorClear = now;
    }
  }

  /// Log error only once per error type
  static void _logOnce(String key, String message) {
    _clearOldErrors();
    if (!_loggedErrors.contains(key)) {
      _loggedErrors.add(key);
      debugPrint(message);
    }
  }

  /// Check if we can make authenticated calls
  static bool get canMakeAuthCalls {
    if (!SupabaseService.isReady) {
      _logOnce('not_ready', 'Repository: Supabase not ready');
      return false;
    }
    if (SupabaseService.currentUser == null) {
      _logOnce('not_auth', 'Repository: User not authenticated');
      return false;
    }
    return true;
  }

  /// Check if we can make authenticated calls, with async session refresh
  static Future<bool> canMakeAuthCallsAsync() async {
    if (!SupabaseService.isReady) {
      _logOnce('not_ready', 'Repository: Supabase not ready');
      return false;
    }

    // Check if user is null but we might have an expired session
    if (SupabaseService.currentUser == null) {
      // Try to refresh the session
      final refreshed = await SupabaseService.refreshSession();
      if (!refreshed || SupabaseService.currentUser == null) {
        _logOnce('not_auth', 'Repository: User not authenticated');
        return false;
      }
      debugPrint('Repository: Session refreshed successfully');
    }

    // Check if session needs refresh soon
    if (SupabaseService.sessionNeedsRefresh()) {
      await SupabaseService.refreshSession();
    }

    return true;
  }

  /// Check if we can make public calls
  static bool get canMakePublicCalls {
    if (!SupabaseService.isReady) {
      _logOnce('not_ready', 'Repository: Supabase not ready');
      return false;
    }
    return true;
  }

  /// Get the authenticated client (or null if not available)
  static SupabaseClient? get authClient {
    if (!canMakeAuthCalls) return null;
    try {
      return SupabaseService.client;
    } catch (e) {
      return null;
    }
  }

  /// Get the public client
  static SupabaseClient get publicClient => SupabaseService.publicClient;

  /// Execute an authenticated query with error handling
  static Future<RepoResult<T>> executeAuth<T>({
    required String operation,
    required Future<T> Function(SupabaseClient client) query,
    T? defaultValue,
  }) async {
    // Try to ensure we have a valid session
    final canProceed = await canMakeAuthCallsAsync();
    if (!canProceed) {
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure('Not authenticated');
    }

    try {
      final result = await query(SupabaseService.client);
      return RepoResult.success(result);
    } on PostgrestException catch (e) {
      // Check if this is an auth error that might be fixable by refresh
      if (e.code == 'PGRST301' || e.message.contains('JWT')) {
        // Try to refresh and retry once
        final refreshed = await SupabaseService.refreshSession();
        if (refreshed) {
          try {
            final result = await query(SupabaseService.client);
            return RepoResult.success(result);
          } catch (_) {
            // Retry failed, return original error
          }
        }
      }
      _logOnce('postgrest_$operation', 'Repository [$operation]: ${e.message}');
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure(e.message);
    } catch (e) {
      _logOnce('error_$operation', 'Repository [$operation]: $e');
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure(e.toString());
    }
  }

  /// Execute a public query with error handling
  static Future<RepoResult<T>> executePublic<T>({
    required String operation,
    required Future<T> Function(SupabaseClient client) query,
    T? defaultValue,
  }) async {
    if (!canMakePublicCalls) {
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure('Supabase not ready');
    }

    try {
      final result = await query(publicClient);
      return RepoResult.success(result);
    } on PostgrestException catch (e) {
      _logOnce('postgrest_$operation', 'Repository [$operation]: ${e.message}');
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure(e.message);
    } catch (e) {
      _logOnce('error_$operation', 'Repository [$operation]: $e');
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure(e.toString());
    }
  }

  /// Execute RPC call with error handling
  static Future<RepoResult<T>> executeRpc<T>({
    required String functionName,
    Map<String, dynamic>? params,
    required T Function(dynamic response) parser,
    T? defaultValue,
    bool requiresAuth = true,
  }) async {
    if (requiresAuth) {
      final canProceed = await canMakeAuthCallsAsync();
      if (!canProceed) {
        return defaultValue != null
            ? RepoResult.success(defaultValue)
            : RepoResult.failure('Not authenticated');
      }
    } else if (!canMakePublicCalls) {
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure('Supabase not ready');
    }

    final client = requiresAuth ? SupabaseService.client : publicClient;

    try {
      final response = await client.rpc(functionName, params: params);
      final result = parser(response);
      return RepoResult.success(result);
    } on PostgrestException catch (e) {
      // Check if this is an auth error that might be fixable by refresh
      if (requiresAuth && (e.code == 'PGRST301' || e.message.contains('JWT'))) {
        final refreshed = await SupabaseService.refreshSession();
        if (refreshed) {
          try {
            final response = await SupabaseService.client.rpc(functionName, params: params);
            final result = parser(response);
            return RepoResult.success(result);
          } catch (_) {
            // Retry failed
          }
        }
      }
      _logOnce('rpc_$functionName', 'Repository [RPC:$functionName]: ${e.message}');
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure(e.message);
    } catch (e) {
      _logOnce('rpc_error_$functionName', 'Repository [RPC:$functionName]: $e');
      return defaultValue != null
          ? RepoResult.success(defaultValue)
          : RepoResult.failure(e.toString());
    }
  }
}
