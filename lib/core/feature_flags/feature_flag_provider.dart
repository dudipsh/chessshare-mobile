import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_flag_service.dart';
import 'feature_flags.dart';

/// Provider for the FeatureFlagService
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService(Supabase.instance.client);
});

/// State for feature flags
class FeatureFlagState {
  final Map<FeatureFlag, bool> flags;
  final bool isLoading;
  final String? error;

  const FeatureFlagState({
    this.flags = const {},
    this.isLoading = false,
    this.error,
  });

  FeatureFlagState copyWith({
    Map<FeatureFlag, bool>? flags,
    bool? isLoading,
    String? error,
  }) {
    return FeatureFlagState(
      flags: flags ?? this.flags,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Check if a specific flag is enabled
  bool isEnabled(FeatureFlag flag) => flags[flag] ?? false;
}

/// Notifier for managing feature flag state
class FeatureFlagNotifier extends StateNotifier<FeatureFlagState> {
  final FeatureFlagService _service;

  FeatureFlagNotifier(this._service) : super(const FeatureFlagState(isLoading: true)) {
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final flagMap = <FeatureFlag, bool>{};

      // Load all defined flags
      for (final flag in FeatureFlag.values) {
        final enabled = await _service.isEnabled(flag);
        flagMap[flag] = enabled;
      }

      state = FeatureFlagState(
        flags: flagMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh flags from server
  Future<void> refresh() async {
    await _service.refresh();
    await _loadFlags();
  }

  /// Clear flags (call on logout)
  void clear() {
    _service.clearCache();
    state = const FeatureFlagState();
  }

  /// Check if a flag is enabled (synchronous, uses cached state)
  bool isEnabled(FeatureFlag flag) => state.isEnabled(flag);

  /// Check if all flags are enabled
  bool areAllEnabled(List<FeatureFlag> flags) {
    return flags.every((f) => state.isEnabled(f));
  }

  /// Check if any flag is enabled
  bool isAnyEnabled(List<FeatureFlag> flags) {
    return flags.any((f) => state.isEnabled(f));
  }
}

/// Provider for feature flag state
final featureFlagProvider =
    StateNotifierProvider<FeatureFlagNotifier, FeatureFlagState>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return FeatureFlagNotifier(service);
});

/// Convenience provider for checking a single flag
final isFeatureEnabledProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  final state = ref.watch(featureFlagProvider);
  return state.isEnabled(flag);
});

/// Provider to check if free user limits are enabled
final freeUserLimitsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFeatureEnabledProvider(FeatureFlag.freeUserLimits));
});

/// Provider to check if gamification is enabled
final gamificationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFeatureEnabledProvider(FeatureFlag.gamification));
});

/// Provider to check if daily puzzles are enabled
final dailyPuzzlesEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFeatureEnabledProvider(FeatureFlag.dailyPuzzles));
});
