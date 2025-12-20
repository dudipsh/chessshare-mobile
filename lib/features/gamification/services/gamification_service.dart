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
  Map<String, int>? _xpConfig;

  GamificationService(this._client);

  // ============ XP Configuration ============

  /// Fetch XP configuration from server
  Future<Map<String, int>> getXpConfiguration() async {
    if (_xpConfig != null) return _xpConfig!;

    try {
      final response = await _client
          .from('xp_configuration')
          .select('event_type, xp_value')
          .eq('is_active', true);

      _xpConfig = {};
      for (final row in response) {
        final eventType = row['event_type'] as String;
        final xpValue = row['xp_value'] as int;
        _xpConfig![eventType] = xpValue;
      }

      return _xpConfig!;
    } catch (e) {
      print('GamificationService: Error fetching XP config: $e');
      // Return default values
      return {
        for (final type in XpEventType.values)
          type.code: type.defaultXp,
      };
    }
  }

  /// Get XP value for an event type
  Future<int> getXpForEvent(XpEventType eventType) async {
    final config = await getXpConfiguration();
    return config[eventType.code] ?? eventType.defaultXp;
  }

  // ============ User XP Profile ============

  /// Get user's XP profile
  Future<UserXpProfile> getUserProfile(String userId) async {
    if (_cachedProfile != null && _cachedProfile!.userId == userId) {
      return _cachedProfile!;
    }

    try {
      final response = await _client
          .from('user_xp')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _cachedProfile = UserXpProfile.fromJson(response);
      } else {
        _cachedProfile = UserXpProfile.empty(userId);
      }

      return _cachedProfile!;
    } catch (e) {
      print('GamificationService: Error fetching user profile: $e');
      return UserXpProfile.empty(userId);
    }
  }

  // ============ Award XP ============

  /// Award XP for an event
  Future<XpAwardResult> awardXp(
    String userId,
    XpEventType eventType, {
    String? relatedId,
    int? customXp,
  }) async {
    // Get current profile
    final profile = await getUserProfile(userId);
    final oldTotalXp = profile.totalXp;

    // Get XP value
    final xpToAward = customXp ?? await getXpForEvent(eventType);

    if (xpToAward <= 0) {
      return XpAwardResult.local(xpAwarded: 0, oldTotalXp: oldTotalXp);
    }

    try {
      // Try to use RPC for atomic operation
      final response = await _client.rpc('add_xp_event', params: {
        'user_uuid': userId,
        'event_type_code': eventType.code,
        'xp_to_add': xpToAward,
        'related_uuid': relatedId,
      });

      if (response is Map) {
        final result = XpAwardResult.fromJson(response as Map<String, dynamic>);
        // Update cache
        _cachedProfile = UserXpProfile(
          userId: userId,
          totalXp: result.newTotalXp,
          levelInfo: LevelInfo.fromXp(result.newTotalXp),
          lastUpdated: DateTime.now(),
        );
        return result;
      }
    } catch (e) {
      print('GamificationService: RPC error (add_xp_event): $e');
    }

    // Fallback: Local calculation (for offline or when RPC unavailable)
    final result = XpAwardResult.local(xpAwarded: xpToAward, oldTotalXp: oldTotalXp);

    // Update cache
    _cachedProfile = UserXpProfile(
      userId: userId,
      totalXp: result.newTotalXp,
      levelInfo: LevelInfo.fromXp(result.newTotalXp),
      lastUpdated: DateTime.now(),
    );

    // Try to sync to database
    try {
      await _client.from('user_xp').upsert({
        'user_id': userId,
        'total_xp': result.newTotalXp,
        'level': result.newLevel,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Record the event
      await _client.from('xp_events').insert({
        'user_id': userId,
        'event_type': eventType.code,
        'xp_amount': xpToAward,
        'related_id': relatedId,
      });
    } catch (e) {
      print('GamificationService: Error syncing XP: $e');
      // Save locally for later sync
      await _saveOfflineXp(userId, eventType, xpToAward, relatedId);
    }

    return result;
  }

  // ============ Daily Login Streak ============

  /// Get user's login streak
  Future<LoginStreak> getStreak(String userId) async {
    if (_cachedStreak != null && _cachedStreak!.userId == userId) {
      return _cachedStreak!;
    }

    try {
      final response = await _client
          .from('daily_login_streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _cachedStreak = LoginStreak.fromJson(response);
      } else {
        _cachedStreak = LoginStreak.empty(userId);
      }

      return _cachedStreak!;
    } catch (e) {
      print('GamificationService: Error fetching streak: $e');
      return LoginStreak.empty(userId);
    }
  }

  /// Check and update daily login
  Future<StreakCheckResult> checkDailyLogin(String userId) async {
    final streak = await getStreak(userId);

    // Already logged in today
    if (streak.loggedInToday) {
      return StreakCheckResult.alreadyLoggedIn(streak.currentStreak);
    }

    // Calculate new streak
    int newStreak;
    bool streakBroken = false;

    if (streak.isActive) {
      // Continue streak
      newStreak = streak.currentStreak + 1;
    } else {
      // Streak broken, start fresh
      newStreak = 1;
      streakBroken = streak.currentStreak > 0;
    }

    // Create result
    final result = StreakCheckResult.newLogin(
      newStreak: newStreak,
      streakBroken: streakBroken,
    );

    // Update streak in database
    try {
      final response = await _client.rpc('check_daily_login', params: {
        'user_uuid': userId,
      });

      // RPC returns the streak bonus XP if any
      if (response is Map && response['streak'] != null) {
        final serverStreak = response['streak'] as int;
        // Award streak bonus XP if applicable
        if (result.xpBonus > 0) {
          await awardXp(
            userId,
            XpEventType.dailyLoginStreak,
            customXp: result.xpBonus,
          );
        }
      }
    } catch (e) {
      print('GamificationService: RPC error (check_daily_login): $e');

      // Fallback: Update directly
      try {
        await _client.from('daily_login_streaks').upsert({
          'user_id': userId,
          'current_streak': newStreak,
          'longest_streak': newStreak > streak.longestStreak ? newStreak : streak.longestStreak,
          'last_login_date': DateTime.now().toIso8601String().split('T')[0],
        });

        // Award streak bonus
        if (result.xpBonus > 0) {
          await awardXp(
            userId,
            XpEventType.dailyLoginStreak,
            customXp: result.xpBonus,
          );
        }
      } catch (e2) {
        print('GamificationService: Error updating streak: $e2');
      }
    }

    // Update cache
    _cachedStreak = LoginStreak(
      userId: userId,
      currentStreak: newStreak,
      longestStreak: newStreak > streak.longestStreak ? newStreak : streak.longestStreak,
      lastLoginDate: DateTime.now(),
    );

    return result;
  }

  // ============ Utility ============

  /// Clear all caches
  void clearCache() {
    _cachedProfile = null;
    _cachedStreak = null;
    _xpConfig = null;
  }

  /// Save offline XP for later sync
  Future<void> _saveOfflineXp(
    String userId,
    XpEventType eventType,
    int xpAmount,
    String? relatedId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_xp_$userId';
      final existing = prefs.getStringList(key) ?? [];

      // Store as: "eventType|xpAmount|relatedId|timestamp"
      final entry = '${eventType.code}|$xpAmount|${relatedId ?? ''}|${DateTime.now().toIso8601String()}';
      existing.add(entry);

      await prefs.setStringList(key, existing);
    } catch (e) {
      print('GamificationService: Error saving offline XP: $e');
    }
  }

  /// Sync offline XP when online
  Future<void> syncOfflineXp(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_xp_$userId';
      final entries = prefs.getStringList(key);

      if (entries == null || entries.isEmpty) return;

      for (final entry in entries) {
        final parts = entry.split('|');
        if (parts.length >= 3) {
          final eventType = XpEventType.fromCode(parts[0]);
          final xpAmount = int.tryParse(parts[1]) ?? 0;
          final relatedId = parts[2].isNotEmpty ? parts[2] : null;

          if (eventType != null && xpAmount > 0) {
            try {
              await _client.from('xp_events').insert({
                'user_id': userId,
                'event_type': eventType.code,
                'xp_amount': xpAmount,
                'related_id': relatedId,
              });
            } catch (e) {
              print('GamificationService: Error syncing offline event: $e');
            }
          }
        }
      }

      // Clear synced entries
      await prefs.remove(key);
    } catch (e) {
      print('GamificationService: Error syncing offline XP: $e');
    }
  }
}
