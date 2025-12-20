/// Types of XP-earning events
enum XpEventType {
  studyLineComplete('study_line_complete', 50),
  dailyPuzzleSolve('daily_puzzle_solve', 25),
  puzzleSolve('puzzle_solve', 15), // Regular puzzle solve (from game review)
  gameAnalysisComplete('game_analysis_complete', 30),
  dailyLoginStreak('daily_login_streak', 0), // Variable based on streak
  practiceMistakeCorrect('practice_mistake_correct', 15),
  firstBoardCreated('first_board_created', 100),
  profileComplete('profile_complete', 50);

  final String code;
  final int defaultXp;

  const XpEventType(this.code, this.defaultXp);

  static XpEventType? fromCode(String code) {
    try {
      return XpEventType.values.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// Model representing an XP event
class XpEvent {
  final String id;
  final String userId;
  final XpEventType eventType;
  final int xpAmount;
  final String? relatedId; // e.g., board_id, game_id
  final DateTime createdAt;

  const XpEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.xpAmount,
    this.relatedId,
    required this.createdAt,
  });

  factory XpEvent.fromJson(Map<String, dynamic> json) {
    return XpEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventType: XpEventType.fromCode(json['event_type'] as String) ?? XpEventType.dailyLoginStreak,
      xpAmount: json['xp_amount'] as int,
      relatedId: json['related_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Level information
class LevelInfo {
  final int level;
  final String title;
  final int currentXp;
  final int xpForCurrentLevel;
  final int xpForNextLevel;

  const LevelInfo({
    required this.level,
    required this.title,
    required this.currentXp,
    required this.xpForCurrentLevel,
    required this.xpForNextLevel,
  });

  /// XP per level constant
  static const xpPerLevel = 200;

  /// Calculate level from total XP
  /// Formula: Level = floor(XP / 200) + 1
  static int levelFromXp(int totalXp) {
    return (totalXp ~/ xpPerLevel) + 1;
  }

  /// Calculate XP needed for a specific level
  static int xpForLevel(int level) {
    return (level - 1) * xpPerLevel;
  }

  /// Get title for level
  static String titleForLevel(int level) {
    if (level >= 25) return 'Legend';
    if (level >= 20) return 'Grandmaster';
    if (level >= 15) return 'Chess Master';
    if (level >= 10) return 'Strategist';
    if (level >= 5) return 'Tactician';
    if (level >= 3) return 'Chess Explorer';
    if (level >= 2) return 'Apprentice';
    return 'Beginner';
  }

  /// Create from total XP
  factory LevelInfo.fromXp(int totalXp) {
    final level = levelFromXp(totalXp);
    final xpForCurrent = xpForLevel(level);
    final xpForNext = xpForLevel(level + 1);

    return LevelInfo(
      level: level,
      title: titleForLevel(level),
      currentXp: totalXp,
      xpForCurrentLevel: xpForCurrent,
      xpForNextLevel: xpForNext,
    );
  }

  /// Progress to next level (0.0 to 1.0)
  double get progressToNextLevel {
    final xpInCurrentLevel = currentXp - xpForCurrentLevel;
    final xpNeededForLevel = xpForNextLevel - xpForCurrentLevel;
    return xpInCurrentLevel / xpNeededForLevel;
  }

  /// XP remaining to next level
  int get xpToNextLevel => xpForNextLevel - currentXp;
}

/// User XP profile
class UserXpProfile {
  final String userId;
  final int totalXp;
  final LevelInfo levelInfo;
  final DateTime? lastUpdated;

  const UserXpProfile({
    required this.userId,
    required this.totalXp,
    required this.levelInfo,
    this.lastUpdated,
  });

  factory UserXpProfile.fromJson(Map<String, dynamic> json) {
    final totalXp = json['total_xp'] as int? ?? 0;
    return UserXpProfile(
      userId: json['user_id'] as String,
      totalXp: totalXp,
      levelInfo: LevelInfo.fromXp(totalXp),
      lastUpdated: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  factory UserXpProfile.empty(String userId) {
    return UserXpProfile(
      userId: userId,
      totalXp: 0,
      levelInfo: LevelInfo.fromXp(0),
    );
  }
}

/// Result of awarding XP
class XpAwardResult {
  final int xpAwarded;
  final int newTotalXp;
  final int oldLevel;
  final int newLevel;
  final bool leveledUp;
  final String? newTitle;

  const XpAwardResult({
    required this.xpAwarded,
    required this.newTotalXp,
    required this.oldLevel,
    required this.newLevel,
    required this.leveledUp,
    this.newTitle,
  });

  factory XpAwardResult.fromJson(Map<String, dynamic> json) {
    final oldLevel = json['old_level'] as int? ?? 1;
    final newLevel = json['new_level'] as int? ?? 1;
    final leveledUp = newLevel > oldLevel;

    return XpAwardResult(
      xpAwarded: json['xp_awarded'] as int? ?? 0,
      newTotalXp: json['new_total_xp'] as int? ?? 0,
      oldLevel: oldLevel,
      newLevel: newLevel,
      leveledUp: leveledUp,
      newTitle: leveledUp ? LevelInfo.titleForLevel(newLevel) : null,
    );
  }

  /// Create result for local XP award
  factory XpAwardResult.local({
    required int xpAwarded,
    required int oldTotalXp,
  }) {
    final newTotalXp = oldTotalXp + xpAwarded;
    final oldLevel = LevelInfo.levelFromXp(oldTotalXp);
    final newLevel = LevelInfo.levelFromXp(newTotalXp);

    return XpAwardResult(
      xpAwarded: xpAwarded,
      newTotalXp: newTotalXp,
      oldLevel: oldLevel,
      newLevel: newLevel,
      leveledUp: newLevel > oldLevel,
      newTitle: newLevel > oldLevel ? LevelInfo.titleForLevel(newLevel) : null,
    );
  }
}
