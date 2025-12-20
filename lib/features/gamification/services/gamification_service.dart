import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/xp_models.dart';
import '../models/streak_models.dart';

/// Service for managing XP, levels, and streaks
class GamificationService {
  final SupabaseClient _client;

  // Local cache
  UserXpProfile? _cachedProfile;
  LoginStreak? _cachedStreak;

  GamificationService(this._client);

  // ============ User XP Profile ============

  /// Get user's XP profile using server RPC
  Future<UserXpProfile> getUserProfile(String userId) async {
    if (_cachedProfile != null && _cachedProfile!.userId == userId) {
      return _cachedProfile!;
    }

    try {
      // Use the existing RPC function from the server
      final response = await _client.rpc('get_user_xp_level', params: {
        'target_user_id': userId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        final xp = data['xp'] as int? ?? 0;
        final level = data['level'] as int? ?? 1;

        _cachedProfile = UserXpProfile(
          userId: userId,
          totalXp: xp,
          levelInfo: LevelInfo.fromXp(xp),
          lastUpdated: DateTime.now(),
        );
        return _cachedProfile!;
      }
    } catch (e) {
      // RPC might not exist or other error - use empty profile
    }

    _cachedProfile = UserXpProfile.empty(userId);
    return _cachedProfile!;
  }

  // ============ Award XP ============

  /// Award XP for an event (calls server Edge Function)
  Future<XpAwardResult> awardXp(
    String userId,
    XpEventType eventType, {
    String? relatedId,
    int? customXp,
  }) async {
    final profile = await getUserProfile(userId);
    final oldTotalXp = profile.totalXp;

    try {
      // Call the add-xp-event Edge Function
      final response = await _client.functions.invoke(
        'add-xp-event',
        body: {
          'userId': userId,
          'eventSource': eventType.code,
          'relatedId': relatedId,
        },
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final xpGained = data['xpGained'] as int? ?? 0;
        final levelUpInfo = data['levelUpInfo'] as Map<String, dynamic>?;

        if (xpGained > 0) {
          final newTotalXp = oldTotalXp + xpGained;
          final oldLevel = LevelInfo.levelFromXp(oldTotalXp);
          final newLevel = LevelInfo.levelFromXp(newTotalXp);

          // Update cache
          _cachedProfile = UserXpProfile(
            userId: userId,
            totalXp: newTotalXp,
            levelInfo: LevelInfo.fromXp(newTotalXp),
            lastUpdated: DateTime.now(),
          );

          return XpAwardResult(
            xpAwarded: xpGained,
            newTotalXp: newTotalXp,
            oldLevel: oldLevel,
            newLevel: newLevel,
            leveledUp: newLevel > oldLevel,
            newTitle: newLevel > oldLevel ? LevelInfo.titleForLevel(newLevel) : null,
          );
        }
      }
    } catch (e) {
      // Edge function might not exist - use fallback
    }

    return XpAwardResult.local(xpAwarded: 0, oldTotalXp: oldTotalXp);
  }

  // ============ Daily Login Streak ============

  /// Get user's login streak
  Future<LoginStreak> getStreak(String userId) async {
    if (_cachedStreak != null && _cachedStreak!.userId == userId) {
      return _cachedStreak!;
    }

    try {
      // Use the existing RPC function from the server
      final response = await _client.rpc('get_user_login_streak', params: {
        'p_user_id': userId,
      });

      if (response != null && response is Map<String, dynamic>) {
        _cachedStreak = LoginStreak(
          userId: userId,
          currentStreak: response['current_streak'] as int? ?? 0,
          longestStreak: response['longest_streak'] as int? ?? 0,
          lastLoginDate: response['last_login_date'] != null
              ? DateTime.parse(response['last_login_date'] as String)
              : null,
        );
        return _cachedStreak!;
      }
    } catch (e) {
      // RPC might not exist
    }

    _cachedStreak = LoginStreak.empty(userId);
    return _cachedStreak!;
  }

  /// Check and update daily login
  Future<StreakCheckResult> checkDailyLogin(String userId) async {
    final streak = await getStreak(userId);

    // Already logged in today
    if (streak.loggedInToday) {
      return StreakCheckResult.alreadyLoggedIn(streak.currentStreak);
    }

    try {
      // Use the existing RPC function from the server
      final response = await _client.rpc('check_and_award_daily_login', params: {
        'p_user_id': userId,
      });

      if (response != null && response is Map<String, dynamic>) {
        final streakCount = response['streak_count'] as int? ?? 1;
        final xpAwarded = response['xp_awarded'] as int? ?? 0;
        final showPopup = response['show_popup'] as bool? ?? true;

        // Update cache
        _cachedStreak = LoginStreak(
          userId: userId,
          currentStreak: streakCount,
          longestStreak: streakCount > streak.longestStreak ? streakCount : streak.longestStreak,
          lastLoginDate: DateTime.now(),
        );

        // Refresh XP profile
        _cachedProfile = null;
        await getUserProfile(userId);

        if (showPopup) {
          return StreakCheckResult.newLogin(
            newStreak: streakCount,
            streakBroken: false,
          );
        }
      }
    } catch (e) {
      // RPC might not exist
    }

    return StreakCheckResult.alreadyLoggedIn(streak.currentStreak);
  }

  // ============ Utility ============

  /// Clear all caches
  void clearCache() {
    _cachedProfile = null;
    _cachedStreak = null;
  }

  /// Force refresh from server
  Future<void> refresh(String userId) async {
    clearCache();
    await getUserProfile(userId);
    await getStreak(userId);
  }
}
