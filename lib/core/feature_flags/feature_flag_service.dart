import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_flags.dart';

/// Service for fetching and managing feature flags from Supabase
class FeatureFlagService {
  final SupabaseClient _client;

  /// Cache of loaded flags
  final Map<String, bool> _flagCache = {};

  /// Last fetch timestamp
  DateTime? _lastFetch;

  /// Cache duration (5 minutes)
  static const _cacheDuration = Duration(minutes: 5);

  FeatureFlagService(this._client);

  /// Check if a feature flag is enabled for the current user
  Future<bool> isEnabled(FeatureFlag flag) async {
    await _ensureFlagsLoaded();
    return _flagCache[flag.code] ?? false;
  }

  /// Check if multiple flags are all enabled
  Future<bool> areAllEnabled(List<FeatureFlag> flags) async {
    await _ensureFlagsLoaded();
    return flags.every((f) => _flagCache[f.code] ?? false);
  }

  /// Check if any of the flags are enabled
  Future<bool> isAnyEnabled(List<FeatureFlag> flags) async {
    await _ensureFlagsLoaded();
    return flags.any((f) => _flagCache[f.code] ?? false);
  }

  /// Force refresh flags from server
  Future<void> refresh() async {
    _lastFetch = null;
    await _loadFlags();
  }

  /// Clear cache (call on logout)
  void clearCache() {
    _flagCache.clear();
    _lastFetch = null;
  }

  /// Ensure flags are loaded (with caching)
  Future<void> _ensureFlagsLoaded() async {
    final now = DateTime.now();
    if (_lastFetch != null && now.difference(_lastFetch!) < _cacheDuration) {
      return; // Use cached values
    }
    await _loadFlags();
  }

  /// Load flags from Supabase
  Future<void> _loadFlags() async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId != null) {
        // Try to fetch user-specific flags via RPC
        final result = await _client.rpc(
          'get_user_feature_flags',
          params: {'user_uuid': userId},
        );

        if (result is List) {
          _flagCache.clear();
          for (final row in result) {
            final code = row['code'] as String?;
            final enabled = row['enabled'] as bool? ?? false;
            if (code != null) {
              _flagCache[code] = enabled;
            }
          }
          _lastFetch = DateTime.now();
          return;
        }
      }

      // Fallback: Load global flags only
      await _loadGlobalFlags();
    } catch (e) {
      // RPC might not exist, fallback to global flags
      print('FeatureFlagService: Error loading user flags: $e');
      await _loadGlobalFlags();
    }
  }

  /// Load global flags (fallback when RPC not available)
  Future<void> _loadGlobalFlags() async {
    try {
      final response = await _client
          .from('feature_flags')
          .select('code, is_globally_enabled')
          .eq('is_globally_enabled', true);

      _flagCache.clear();
      for (final row in response) {
        final code = row['code'] as String?;
        if (code != null) {
          _flagCache[code] = true;
        }
      }
      _lastFetch = DateTime.now();
    } catch (e) {
      print('FeatureFlagService: Error loading global flags: $e');
      // On error, keep existing cache or use defaults
      if (_flagCache.isEmpty) {
        _setDefaultFlags();
      }
    }
  }

  /// Set default flags when database is unavailable
  void _setDefaultFlags() {
    // By default, enable core features that should always work
    _flagCache[FeatureFlag.freeUserLimits.code] = true;
    _flagCache[FeatureFlag.freeUserBoardLimits.code] = true;
    _lastFetch = DateTime.now();
  }

  /// Get all currently cached flags (for debugging)
  Map<String, bool> get cachedFlags => Map.unmodifiable(_flagCache);
}
