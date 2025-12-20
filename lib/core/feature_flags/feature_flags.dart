/// Feature flags that can be toggled remotely or per-user
enum FeatureFlag {
  /// Enable subscription-based limits for free users
  freeUserLimits('free_user_limits'),

  /// Enable free user board view limits
  freeUserBoardLimits('free_user_board_limits'),

  /// Enable gamification system (XP & Levels)
  gamification('gamification'),

  /// Enable daily puzzles feature
  dailyPuzzles('daily_puzzles'),

  /// Enable practice mistakes with spaced repetition
  practiceMistakes('practice_mistakes'),

  /// Allow users to create study boards
  boardCreation('board_creation'),

  /// Enable clubs system
  clubs('clubs'),

  /// Enable local notification reminders
  localNotifications('local_notifications'),

  /// Enable push notifications (Firebase)
  pushNotifications('push_notifications'),

  /// Enable multi-language support
  multiLanguage('multi_language'),

  /// Enable theme customization
  themeCustomization('theme_customization'),

  /// Enable library system
  libraries('libraries'),

  /// Enable search & discovery
  searchDiscovery('search_discovery'),

  /// Enable follow system
  followSystem('follow_system'),

  /// Enable leaderboard
  leaderboard('leaderboard');

  final String code;

  const FeatureFlag(this.code);

  /// Get flag by code string
  static FeatureFlag? fromCode(String code) {
    try {
      return FeatureFlag.values.firstWhere((f) => f.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// Model representing a feature flag from the database
class FeatureFlagModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final bool isGloballyEnabled;
  final DateTime? createdAt;

  const FeatureFlagModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.isGloballyEnabled,
    this.createdAt,
  });

  factory FeatureFlagModel.fromJson(Map<String, dynamic> json) {
    return FeatureFlagModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isGloballyEnabled: json['is_globally_enabled'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// Model for user-specific feature flag override
class UserFeatureFlag {
  final String userId;
  final String flagId;
  final bool enabled;

  const UserFeatureFlag({
    required this.userId,
    required this.flagId,
    required this.enabled,
  });

  factory UserFeatureFlag.fromJson(Map<String, dynamic> json) {
    return UserFeatureFlag(
      userId: json['user_id'] as String,
      flagId: json['flag_id'] as String,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}
