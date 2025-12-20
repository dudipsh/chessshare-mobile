import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/xp_models.dart';
import '../models/streak_models.dart';
import '../services/gamification_service.dart';

/// Provider for the GamificationService
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return GamificationService(Supabase.instance.client);
});

/// State for gamification
class GamificationState {
  final UserXpProfile? profile;
  final LoginStreak? streak;
  final bool isLoading;
  final String? error;

  // Pending XP award to show in UI
  final XpAwardResult? pendingXpAward;
  final StreakCheckResult? pendingStreakResult;

  const GamificationState({
    this.profile,
    this.streak,
    this.isLoading = false,
    this.error,
    this.pendingXpAward,
    this.pendingStreakResult,
  });

  GamificationState copyWith({
    UserXpProfile? profile,
    LoginStreak? streak,
    bool? isLoading,
    String? error,
    XpAwardResult? pendingXpAward,
    StreakCheckResult? pendingStreakResult,
    bool clearPendingXp = false,
    bool clearPendingStreak = false,
  }) {
    return GamificationState(
      profile: profile ?? this.profile,
      streak: streak ?? this.streak,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingXpAward: clearPendingXp ? null : (pendingXpAward ?? this.pendingXpAward),
      pendingStreakResult: clearPendingStreak ? null : (pendingStreakResult ?? this.pendingStreakResult),
    );
  }

  /// Current level
  int get level => profile?.levelInfo.level ?? 1;

  /// Current total XP
  int get totalXp => profile?.totalXp ?? 0;

  /// Level title
  String get levelTitle => profile?.levelInfo.title ?? 'Beginner';

  /// Progress to next level (0.0 to 1.0)
  double get progressToNextLevel => profile?.levelInfo.progressToNextLevel ?? 0.0;

  /// XP to next level
  int get xpToNextLevel => profile?.levelInfo.xpToNextLevel ?? 200;

  /// Current streak
  int get currentStreak => streak?.currentStreak ?? 0;
}

/// Notifier for managing gamification state
class GamificationNotifier extends StateNotifier<GamificationState> {
  final GamificationService _service;
  String? _userId;

  GamificationNotifier(this._service) : super(const GamificationState());

  /// Initialize with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    await _load();
    // Check daily login on initialization
    await checkDailyLogin();
  }

  Future<void> _load() async {
    if (_userId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      final profile = await _service.getUserProfile(_userId!);
      final streak = await _service.getStreak(_userId!);

      state = GamificationState(
        profile: profile,
        streak: streak,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Award XP for an event
  Future<XpAwardResult?> awardXp(
    XpEventType eventType, {
    String? relatedId,
    int? customXp,
  }) async {
    if (_userId == null) return null;

    try {
      final result = await _service.awardXp(
        _userId!,
        eventType,
        relatedId: relatedId,
        customXp: customXp,
      );

      // Update state
      state = state.copyWith(
        profile: UserXpProfile(
          userId: _userId!,
          totalXp: result.newTotalXp,
          levelInfo: LevelInfo.fromXp(result.newTotalXp),
          lastUpdated: DateTime.now(),
        ),
        pendingXpAward: result,
      );

      return result;
    } catch (e) {
      print('GamificationNotifier: Error awarding XP: $e');
      return null;
    }
  }

  /// Check daily login
  Future<StreakCheckResult?> checkDailyLogin() async {
    if (_userId == null) return null;

    try {
      final result = await _service.checkDailyLogin(_userId!);

      if (result.isNewDay) {
        // Refresh profile to get updated XP
        final profile = await _service.getUserProfile(_userId!);

        state = state.copyWith(
          profile: profile,
          streak: LoginStreak(
            userId: _userId!,
            currentStreak: result.newStreak,
            longestStreak: state.streak?.longestStreak ?? result.newStreak,
            lastLoginDate: DateTime.now(),
          ),
          pendingStreakResult: result,
        );
      }

      return result;
    } catch (e) {
      print('GamificationNotifier: Error checking daily login: $e');
      return null;
    }
  }

  /// Clear pending XP award (after showing popup)
  void clearPendingXpAward() {
    state = state.copyWith(clearPendingXp: true);
  }

  /// Clear pending streak result (after showing popup)
  void clearPendingStreakResult() {
    state = state.copyWith(clearPendingStreak: true);
  }

  /// Refresh all gamification data
  Future<void> refresh() async {
    _service.clearCache();
    await _load();
  }

  /// Clear on logout
  void clear() {
    _userId = null;
    _service.clearCache();
    state = const GamificationState();
  }
}

/// Provider for gamification state
final gamificationProvider =
    StateNotifierProvider<GamificationNotifier, GamificationState>((ref) {
  final service = ref.watch(gamificationServiceProvider);
  return GamificationNotifier(service);
});

/// Provider for current level
final currentLevelProvider = Provider<int>((ref) {
  final state = ref.watch(gamificationProvider);
  return state.level;
});

/// Provider for current XP
final currentXpProvider = Provider<int>((ref) {
  final state = ref.watch(gamificationProvider);
  return state.totalXp;
});

/// Provider for current streak
final currentStreakProvider = Provider<int>((ref) {
  final state = ref.watch(gamificationProvider);
  return state.currentStreak;
});
