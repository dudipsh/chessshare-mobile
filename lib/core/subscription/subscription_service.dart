import 'package:supabase_flutter/supabase_flutter.dart';

import '../feature_flags/feature_flags.dart';
import '../feature_flags/feature_flag_service.dart';
import 'limits_tracker.dart';
import 'subscription_tier.dart';

/// Service for managing subscriptions and enforcing limits
class SubscriptionService {
  final SupabaseClient _client;
  final FeatureFlagService _featureFlagService;
  final LimitsTracker _limitsTracker;

  UserSubscription? _cachedSubscription;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 10);

  SubscriptionService(this._client, this._featureFlagService)
      : _limitsTracker = LimitsTracker();

  /// Get current user's subscription
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
      final response = await _client
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        _cachedSubscription = UserSubscription.fromJson(response);
      } else {
        _cachedSubscription = UserSubscription.free(userId);
      }
      _lastFetch = now;

      return _cachedSubscription!;
    } catch (e) {
      print('SubscriptionService: Error fetching subscription: $e');
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

  // ============ Analysis Limits ============

  /// Check if user can analyze a game
  Future<LimitCheckResult> canAnalyzeGame() async {
    if (!await _areLimitsEnabled()) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final limits = await getLimits();
    final used = await _limitsTracker.getUsageCount(LimitedAction.gameAnalysis);

    return LimitCheckResult(
      allowed: used < limits.dailyAnalyses,
      used: used,
      limit: limits.dailyAnalyses,
      message: 'You\'ve reached your daily analysis limit (${limits.dailyAnalyses}). Upgrade to analyze more games.',
    );
  }

  /// Record a game analysis
  Future<void> recordAnalysis() async {
    await _limitsTracker.recordUsage(LimitedAction.gameAnalysis);

    // Also record to Supabase for cross-device sync
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.rpc('record_free_user_analysis', params: {
          'user_uuid': userId,
        });
      } catch (e) {
        // Ignore RPC errors, local tracking is enough
        print('SubscriptionService: RPC error (record_free_user_analysis): $e');
      }
    }
  }

  /// Get remaining analyses for today
  Future<int> getRemainingAnalyses() async {
    if (!await _areLimitsEnabled()) return 999999;

    final limits = await getLimits();
    return await _limitsTracker.getRemainingCount(
      LimitedAction.gameAnalysis,
      limits.dailyAnalyses,
    );
  }

  // ============ Board View Limits ============

  /// Check if user can view a board
  Future<LimitCheckResult> canViewBoard() async {
    final boardLimitsEnabled =
        await _featureFlagService.isEnabled(FeatureFlag.freeUserBoardLimits);
    if (!boardLimitsEnabled) {
      return const LimitCheckResult(allowed: true, used: 0, limit: 999999);
    }

    final limits = await getLimits();
    final used = await _limitsTracker.getUsageCount(LimitedAction.boardView);

    return LimitCheckResult(
      allowed: used < limits.dailyBoardViews,
      used: used,
      limit: limits.dailyBoardViews,
      message: 'You\'ve reached your daily board view limit (${limits.dailyBoardViews}). Upgrade to view more boards.',
    );
  }

  /// Record a board view
  Future<void> recordBoardView(String boardId) async {
    await _limitsTracker.recordUsage(LimitedAction.boardView);

    // Also record to Supabase
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.rpc('record_free_user_board_view', params: {
          'user_uuid': userId,
          'board_uuid': boardId,
        });
      } catch (e) {
        print('SubscriptionService: RPC error (record_free_user_board_view): $e');
      }
    }
  }

  /// Get remaining board views for today
  Future<int> getRemainingBoardViews() async {
    final boardLimitsEnabled =
        await _featureFlagService.isEnabled(FeatureFlag.freeUserBoardLimits);
    if (!boardLimitsEnabled) return 999999;

    final limits = await getLimits();
    return await _limitsTracker.getRemainingCount(
      LimitedAction.boardView,
      limits.dailyBoardViews,
    );
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

    if (limits.maxBoards == 0) {
      return LimitCheckResult(
        allowed: false,
        used: currentBoardCount,
        limit: 0,
        message: 'Upgrade to Basic to create study boards.',
      );
    }

    return LimitCheckResult(
      allowed: currentBoardCount < limits.maxBoards,
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
      allowed: used < limits.dailyPuzzles,
      used: used,
      limit: limits.dailyPuzzles,
      message: 'You\'ve completed your daily puzzles. Come back tomorrow!',
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
      allowed: currentMistakeCount < limits.maxSavedMistakes,
      used: currentMistakeCount,
      limit: limits.maxSavedMistakes,
      message: 'You\'ve reached your saved mistakes limit (${limits.maxSavedMistakes}). Upgrade or practice existing ones.',
    );
  }

  // ============ Feature Access ============

  /// Check if user can upload cover images
  Future<bool> canUploadCover() async {
    final limits = await getLimits();
    return limits.canUploadCover;
  }

  /// Check if user can create a club
  Future<bool> canCreateClub() async {
    final limits = await getLimits();
    return limits.canCreateClub;
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
}
