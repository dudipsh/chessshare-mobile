import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feature_flags/feature_flags.dart';
import '../feature_flags/feature_flag_service.dart';
import 'limits_tracker.dart';
import 'subscription_tier.dart';

/// Service for managing subscriptions and enforcing limits
/// Uses the profiles table schema from the web app (chessy-linker)
class SubscriptionService {
  final SupabaseClient _client;
  final FeatureFlagService _featureFlagService;
  final LimitsTracker _limitsTracker;

  UserSubscription? _cachedSubscription;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 5);

  // Realtime subscription for subscription_notifications
  RealtimeChannel? _notificationChannel;
  final _subscriptionUpdatedController = StreamController<UserSubscription>.broadcast();

  SubscriptionService(this._client, this._featureFlagService)
      : _limitsTracker = LimitsTracker();

  /// Stream of subscription updates (from Realtime)
  Stream<UserSubscription> get onSubscriptionUpdated =>
      _subscriptionUpdatedController.stream;

  /// Get current user's subscription from profiles table
  Future<UserSubscription> getSubscription() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return UserSubscription.free('');
    }

    // Check cache
    final now = DateTime.now();
    if (_cachedSubscription != null &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < _cacheDuration) {
      return _cachedSubscription!;
    }

    try {
      // Query profiles table for subscription info
      final response = await _client
          .from('profiles')
          .select('''
            id,
            subscription_type,
            subscription_start_date,
            subscription_end_date,
            lemonsqueezy_subscription_id,
            lemonsqueezy_customer_id
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _cachedSubscription = UserSubscription.fromProfile(response);
      } else {
        _cachedSubscription = UserSubscription.free(userId);
      }
      _lastFetch = now;

      return _cachedSubscription!;
    } catch (e) {
      debugPrint('SubscriptionService: Error fetching subscription: $e');
      return UserSubscription.free(userId);
    }
  }

  /// Get subscription info via RPC (alternative method)
  Future<UserSubscription> getSubscriptionViaRpc() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return UserSubscription.free('');
    }

    try {
      final response = await _client.rpc('get_user_subscription_info', params: {
        'p_user_id': userId,
      });

      if (response != null && response is Map<String, dynamic>) {
        return UserSubscription.fromRpc(userId, response);
      }
      return UserSubscription.free(userId);
    } catch (e) {
      debugPrint('SubscriptionService: RPC error (get_user_subscription_info): $e');
      return UserSubscription.free(userId);
    }
  }

  /// Get current tier limits
  Future<TierLimits> getLimits() async {
    final subscription = await getSubscription();
    return subscription.limits;
  }

  /// Check if limits feature is enabled
  Future<bool> _areLimitsEnabled() async {
    return await _featureFlagService.isEnabled(FeatureFlag.freeUserLimits);
  }

  // ============ Realtime Subscription Updates ============

  /// Start listening for subscription updates via Realtime
  void startListeningForUpdates() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _notificationChannel?.unsubscribe();

    _notificationChannel = _client
        .channel('subscription_notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'subscription_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('SubscriptionService: Received subscription update');
            _handleSubscriptionNotification(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Stop listening for updates
  void stopListeningForUpdates() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
  }

  /// Handle incoming subscription notification
  void _handleSubscriptionNotification(Map<String, dynamic> data) async {
    debugPrint('SubscriptionService: Processing notification: $data');

    // Clear cache and refresh
    _cachedSubscription = null;
    _lastFetch = null;

    final subscription = await getSubscription();
    _subscriptionUpdatedController.add(subscription);
  }

  // ============ Game Review Limits ============

  /// Check if user can analyze/review a game
  Future<LimitCheckResult> canReviewGame() async {
    if (!await _areLimitsEnabled()) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final limits = await getLimits();
    final used = await _getTodayGameReviewCount();

    return LimitCheckResult(
      allowed: used < limits.dailyGameReviews,
      used: used,
      limit: limits.dailyGameReviews,
      message:
          'You\'ve reached your daily game review limit (${limits.dailyGameReviews}). Upgrade to review more games.',
    );
  }

  /// Get today's game review count from Supabase
  Future<int> _getTodayGameReviewCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _client.rpc('get_today_game_review_count', params: {
        'p_user_id': userId,
      });
      return (response as int?) ?? 0;
    } catch (e) {
      debugPrint('SubscriptionService: RPC error (get_today_game_review_count): $e');
      // Fall back to local tracking
      return await _limitsTracker.getUsageCount(LimitedAction.gameAnalysis);
    }
  }

  /// Record a game review
  Future<void> recordGameReview() async {
    await _limitsTracker.recordUsage(LimitedAction.gameAnalysis);
    // Note: The actual recording in Supabase happens via the game review endpoint
  }

  /// Get remaining game reviews for today
  Future<int> getRemainingGameReviews() async {
    if (!await _areLimitsEnabled()) return 999999;

    final limits = await getLimits();
    final used = await _getTodayGameReviewCount();
    return (limits.dailyGameReviews - used).clamp(0, limits.dailyGameReviews);
  }

  // ============ Board View Limits ============

  /// Check if user can view a board (FREE users only)
  Future<LimitCheckResult> canViewBoard(String boardId) async {
    final subscription = await getSubscription();

    // Paid users have no board view limits
    if (subscription.tier != SubscriptionTier.free) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final boardLimitsEnabled =
        await _featureFlagService.isEnabled(FeatureFlag.freeUserBoardLimits);
    if (!boardLimitsEnabled) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const LimitCheckResult(allowed: false, used: 0, limit: 3);
    }

    try {
      // Check via RPC
      final canView = await _client.rpc('can_free_user_view_board', params: {
        'p_user_id': userId,
        'p_board_id': boardId,
      });

      final remaining = await _getRemainingBoardViews();
      final used = subscription.limits.dailyBoardViews - remaining;

      return LimitCheckResult(
        allowed: canView as bool? ?? false,
        used: used,
        limit: subscription.limits.dailyBoardViews,
        message: 'You\'ve reached your daily board view limit (3). Upgrade to view more boards.',
      );
    } catch (e) {
      debugPrint('SubscriptionService: RPC error (can_free_user_view_board): $e');
      // Fall back to local tracking
      final used = await _limitsTracker.getUsageCount(LimitedAction.boardView);
      return LimitCheckResult(
        allowed: used < subscription.limits.dailyBoardViews,
        used: used,
        limit: subscription.limits.dailyBoardViews,
      );
    }
  }

  /// Record a board view
  Future<void> recordBoardView(String boardId) async {
    await _limitsTracker.recordUsage(LimitedAction.boardView);

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.rpc('record_free_user_board_view', params: {
          'p_user_id': userId,
          'p_board_id': boardId,
        });
      } catch (e) {
        debugPrint('SubscriptionService: RPC error (record_free_user_board_view): $e');
      }
    }
  }

  /// Get remaining board views for today
  Future<int> _getRemainingBoardViews() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _client.rpc('get_free_user_remaining_views', params: {
        'p_user_id': userId,
      });
      return (response as int?) ?? 0;
    } catch (e) {
      debugPrint('SubscriptionService: RPC error (get_free_user_remaining_views): $e');
      final limits = await getLimits();
      return await _limitsTracker.getRemainingCount(
        LimitedAction.boardView,
        limits.dailyBoardViews,
      );
    }
  }

  /// Get remaining board views for today (public)
  Future<int> getRemainingBoardViews() async {
    final subscription = await getSubscription();
    if (subscription.tier != SubscriptionTier.free) {
      return 999999; // Unlimited for paid users
    }

    final boardLimitsEnabled =
        await _featureFlagService.isEnabled(FeatureFlag.freeUserBoardLimits);
    if (!boardLimitsEnabled) return 999999;

    return await _getRemainingBoardViews();
  }

  // ============ Variation Access ============

  /// Check if user can access a specific variation
  Future<bool> canAccessVariation(int variationIndex) async {
    if (!await _areLimitsEnabled()) return true;

    final limits = await getLimits();

    // All variations allowed
    if (limits.allVariations) return true;

    // Free users can only access first variation (index 0)
    return variationIndex == 0;
  }

  // ============ Board Creation ============

  /// Check if user can create a board
  Future<LimitCheckResult> canCreateBoard(int currentBoardCount) async {
    if (!await _areLimitsEnabled()) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final limits = await getLimits();

    return LimitCheckResult(
      allowed: currentBoardCount < limits.maxBoards ||
          limits.isUnlimited(limits.maxBoards),
      used: currentBoardCount,
      limit: limits.maxBoards,
      message: 'You\'ve reached your board limit (${limits.maxBoards}). Upgrade to create more.',
    );
  }

  // ============ Daily Puzzles ============

  /// Check if user can solve another daily puzzle
  Future<LimitCheckResult> canSolveDailyPuzzle() async {
    if (!await _areLimitsEnabled()) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final limits = await getLimits();
    final used = await _limitsTracker.getUsageCount(LimitedAction.dailyPuzzle);

    return LimitCheckResult(
      allowed: used < limits.dailyPuzzles || limits.isUnlimited(limits.dailyPuzzles),
      used: used,
      limit: limits.dailyPuzzles,
      message: 'You\'ve completed your daily puzzles. Come back tomorrow or upgrade!',
    );
  }

  /// Record a daily puzzle completion
  Future<void> recordDailyPuzzle() async {
    await _limitsTracker.recordUsage(LimitedAction.dailyPuzzle);
  }

  // ============ Saved Mistakes ============

  /// Check if user can save another mistake
  Future<LimitCheckResult> canSaveMistake(int currentMistakeCount) async {
    if (!await _areLimitsEnabled()) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final limits = await getLimits();

    return LimitCheckResult(
      allowed: currentMistakeCount < limits.maxSavedMistakes ||
          limits.isUnlimited(limits.maxSavedMistakes),
      used: currentMistakeCount,
      limit: limits.maxSavedMistakes,
      message:
          'You\'ve reached your saved mistakes limit (${limits.maxSavedMistakes}). Upgrade or practice existing ones.',
    );
  }

  // ============ Feature Access ============

  /// Check if user can upload/change cover images
  Future<bool> canChangeCover() async {
    final limits = await getLimits();
    return limits.canChangeCover;
  }

  /// Check if user can create a club
  Future<bool> canCreateClub() async {
    final limits = await getLimits();
    return limits.canCreateClub;
  }

  // ============ Plan Change ============

  /// Request a plan change via Edge Function
  Future<bool> changePlan(String newPlan) async {
    try {
      final response = await _client.functions.invoke(
        'change-subscription',
        body: {'newPlan': newPlan},
      );

      if (response.status == 200) {
        // Refresh subscription
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SubscriptionService: Error changing plan: $e');
      return false;
    }
  }

  // ============ Utility ============

  /// Clear cached subscription (call on logout)
  void clearCache() {
    _cachedSubscription = null;
    _lastFetch = null;
  }

  /// Force refresh subscription from server
  Future<void> refresh() async {
    _cachedSubscription = null;
    _lastFetch = null;
    await getSubscription();
  }

  /// Dispose resources
  void dispose() {
    stopListeningForUpdates();
    _subscriptionUpdatedController.close();
  }
}
