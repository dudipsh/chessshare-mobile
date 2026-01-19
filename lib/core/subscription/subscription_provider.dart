import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feature_flags/feature_flag_provider.dart';
import 'subscription_service.dart';
import 'subscription_tier.dart';
import 'limits_tracker.dart';

/// Provider for the SubscriptionService
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final featureFlagService = ref.watch(featureFlagServiceProvider);
  final service = SubscriptionService(Supabase.instance.client, featureFlagService);

  // Start listening for realtime updates
  service.startListeningForUpdates();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// State for subscription and limits
class SubscriptionState {
  final UserSubscription? subscription;
  final TierLimits? limits;
  final bool isLoading;
  final String? error;

  // Remaining quotas
  final int remainingGameReviews;
  final int remainingBoardViews;

  const SubscriptionState({
    this.subscription,
    this.limits,
    this.isLoading = false,
    this.error,
    this.remainingGameReviews = 0,
    this.remainingBoardViews = 0,
  });

  SubscriptionState copyWith({
    UserSubscription? subscription,
    TierLimits? limits,
    bool? isLoading,
    String? error,
    int? remainingGameReviews,
    int? remainingBoardViews,
  }) {
    return SubscriptionState(
      subscription: subscription ?? this.subscription,
      limits: limits ?? this.limits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      remainingGameReviews: remainingGameReviews ?? this.remainingGameReviews,
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

  /// Check if user is basic or higher
  bool get isBasicOrHigher => tier == SubscriptionTier.basic || isPro;
}

/// Notifier for managing subscription state
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionService _service;
  StreamSubscription? _updateSubscription;

  SubscriptionNotifier(this._service) : super(const SubscriptionState(isLoading: true)) {
    _load();
    _listenForUpdates();
  }

  void _listenForUpdates() {
    _updateSubscription = _service.onSubscriptionUpdated.listen((subscription) {
      debugPrint('SubscriptionNotifier: Received subscription update');
      _load(); // Refresh all state
    });
  }

  Future<void> _load() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final subscription = await _service.getSubscription();
      final limits = subscription.limits;
      final remainingGameReviews = await _service.getRemainingGameReviews();
      final remainingBoardViews = await _service.getRemainingBoardViews();

      state = SubscriptionState(
        subscription: subscription,
        limits: limits,
        isLoading: false,
        remainingGameReviews: remainingGameReviews,
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

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  // ============ Limit Checks with Recording ============

  /// Check and record game review
  Future<LimitCheckResult> checkAndRecordGameReview() async {
    final result = await _service.canReviewGame();
    if (result.allowed) {
      await _service.recordGameReview();
      // Update remaining count
      final remaining = await _service.getRemainingGameReviews();
      state = state.copyWith(remainingGameReviews: remaining);
    }
    return result;
  }

  /// Check and record board view
  Future<LimitCheckResult> checkAndRecordBoardView(String boardId) async {
    final result = await _service.canViewBoard(boardId);
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

  /// Check if can create club
  Future<bool> canCreateClub() async {
    return await _service.canCreateClub();
  }

  /// Check if can change cover
  Future<bool> canChangeCover() async {
    return await _service.canChangeCover();
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

/// Provider for checking if user is basic or higher
final isBasicOrHigherProvider = Provider<bool>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.isBasicOrHigher;
});

/// Provider for remaining game reviews
final remainingGameReviewsProvider = Provider<int>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.remainingGameReviews;
});

/// Provider for remaining board views
final remainingBoardViewsProvider = Provider<int>((ref) {
  final state = ref.watch(subscriptionProvider);
  return state.remainingBoardViews;
});
