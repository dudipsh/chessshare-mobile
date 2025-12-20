import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feature_flags/feature_flag_provider.dart';
import 'subscription_service.dart';
import 'subscription_tier.dart';
import 'limits_tracker.dart';

/// Provider for the SubscriptionService
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final featureFlagService = ref.watch(featureFlagServiceProvider);
  return SubscriptionService(Supabase.instance.client, featureFlagService);
});

/// State for subscription and limits
class SubscriptionState {
  final UserSubscription? subscription;
  final TierLimits? limits;
  final bool isLoading;
  final String? error;

  // Remaining quotas
  final int remainingAnalyses;
  final int remainingBoardViews;

  const SubscriptionState({
    this.subscription,
    this.limits,
    this.isLoading = false,
    this.error,
    this.remainingAnalyses = 0,
    this.remainingBoardViews = 0,
  });

  SubscriptionState copyWith({
    UserSubscription? subscription,
    TierLimits? limits,
    bool? isLoading,
    String? error,
    int? remainingAnalyses,
    int? remainingBoardViews,
  }) {
    return SubscriptionState(
      subscription: subscription ?? this.subscription,
      limits: limits ?? this.limits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      remainingAnalyses: remainingAnalyses ?? this.remainingAnalyses,
      remainingBoardViews: remainingBoardViews ?? this.remainingBoardViews,
    );
  }

  /// Current tier
  SubscriptionTier get tier => subscription?.effectiveTier ?? SubscriptionTier.free;

  /// Check if user is on a paid plan
  bool get isPaid => tier != SubscriptionTier.free;

  /// Check if user is admin
  bool get isAdmin => tier == SubscriptionTier.admin;

  /// Check if user is pro
  bool get isPro => tier == SubscriptionTier.pro || isAdmin;
}

/// Notifier for managing subscription state
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionService _service;

  SubscriptionNotifier(this._service) : super(const SubscriptionState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final subscription = await _service.getSubscription();
      final limits = subscription.limits;
      final remainingAnalyses = await _service.getRemainingAnalyses();
      final remainingBoardViews = await _service.getRemainingBoardViews();

      state = SubscriptionState(
        subscription: subscription,
        limits: limits,
        isLoading: false,
        remainingAnalyses: remainingAnalyses,
        remainingBoardViews: remainingBoardViews,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh subscription data
  Future<void> refresh() async {
    await _service.refresh();
    await _load();
  }

  /// Clear on logout
  void clear() {
    _service.clearCache();
    state = const SubscriptionState();
  }

  // ============ Limit Checks with Recording ============

  /// Check and record game analysis
  Future<LimitCheckResult> checkAndRecordAnalysis() async {
    final result = await _service.canAnalyzeGame();
    if (result.allowed) {
      await _service.recordAnalysis();
      // Update remaining count
      final remaining = await _service.getRemainingAnalyses();
      state = state.copyWith(remainingAnalyses: remaining);
    }
    return result;
  }

  /// Check and record board view
  Future<LimitCheckResult> checkAndRecordBoardView(String boardId) async {
    final result = await _service.canViewBoard();
    if (result.allowed) {
      await _service.recordBoardView(boardId);
      // Update remaining count
      final remaining = await _service.getRemainingBoardViews();
      state = state.copyWith(remainingBoardViews: remaining);
    }
    return result;
  }

  /// Check variation access
  Future<bool> canAccessVariation(int index) async {
    return await _service.canAccessVariation(index);
  }

  /// Check board creation
  Future<LimitCheckResult> canCreateBoard(int currentCount) async {
    return await _service.canCreateBoard(currentCount);
  }
}

/// Provider for subscription state
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return SubscriptionNotifier(service);
});

/// Provider for current tier
final currentTierProvider = Provider<SubscriptionTier>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.tier;
});

/// Provider for checking if user is on paid plan
final isPaidUserProvider = Provider<bool>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.isPaid;
});

/// Provider for remaining analyses
final remainingAnalysesProvider = Provider<int>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.remainingAnalyses;
});

/// Provider for remaining board views
final remainingBoardViewsProvider = Provider<int>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.remainingBoardViews;
});
