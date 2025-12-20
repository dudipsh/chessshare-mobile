/// Daily login streak data
class LoginStreak {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoginDate;

  const LoginStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastLoginDate,
  });

  factory LoginStreak.fromJson(Map<String, dynamic> json) {
    return LoginStreak(
      userId: json['user_id'] as String,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastLoginDate: json['last_login_date'] != null
          ? DateTime.parse(json['last_login_date'] as String)
          : null,
    );
  }

  factory LoginStreak.empty(String userId) {
    return LoginStreak(
      userId: userId,
      currentStreak: 0,
      longestStreak: 0,
    );
  }

  /// Check if user already logged in today
  bool get loggedInToday {
    if (lastLoginDate == null) return false;
    final now = DateTime.now();
    return lastLoginDate!.year == now.year &&
        lastLoginDate!.month == now.month &&
        lastLoginDate!.day == now.day;
  }

  /// Check if streak is still active (logged in yesterday or today)
  bool get isActive {
    if (lastLoginDate == null) return false;
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Logged in today
    if (lastLoginDate!.year == now.year &&
        lastLoginDate!.month == now.month &&
        lastLoginDate!.day == now.day) {
      return true;
    }

    // Logged in yesterday
    if (lastLoginDate!.year == yesterday.year &&
        lastLoginDate!.month == yesterday.month &&
        lastLoginDate!.day == yesterday.day) {
      return true;
    }

    return false;
  }
}

/// Streak bonus XP configuration
class StreakBonus {
  /// Get XP bonus for a streak day
  static int getBonus(int streakDay) {
    // Milestone bonuses
    if (streakDay >= 30) return 300;
    if (streakDay >= 14) return 150;
    if (streakDay >= 7) return 75;
    if (streakDay >= 5) return 50;
    if (streakDay >= 3) return 35;
    if (streakDay >= 2) return 25;

    // Day 1 - no streak bonus
    return 0;
  }

  /// Get milestone message
  static String? getMilestoneMessage(int streakDay) {
    switch (streakDay) {
      case 2:
        return '2-day streak! Keep it up!';
      case 3:
        return '3 days in a row! You\'re on fire!';
      case 5:
        return '5-day streak! Halfway to a week!';
      case 7:
        return '1 week streak! Amazing dedication!';
      case 14:
        return '2-week streak! You\'re unstoppable!';
      case 30:
        return '30-day streak! Legendary commitment!';
      default:
        if (streakDay > 30 && streakDay % 30 == 0) {
          return '${streakDay ~/ 30} months streak! Incredible!';
        }
        return null;
    }
  }

  /// All streak milestones
  static const milestones = [2, 3, 5, 7, 14, 30];
}

/// Result of checking daily login
class StreakCheckResult {
  final bool isNewDay;
  final int newStreak;
  final int xpBonus;
  final String? milestoneMessage;
  final bool streakBroken;

  const StreakCheckResult({
    required this.isNewDay,
    required this.newStreak,
    required this.xpBonus,
    this.milestoneMessage,
    this.streakBroken = false,
  });

  /// Already logged in today
  factory StreakCheckResult.alreadyLoggedIn(int currentStreak) {
    return StreakCheckResult(
      isNewDay: false,
      newStreak: currentStreak,
      xpBonus: 0,
    );
  }

  /// New day login
  factory StreakCheckResult.newLogin({
    required int newStreak,
    required bool streakBroken,
  }) {
    return StreakCheckResult(
      isNewDay: true,
      newStreak: newStreak,
      xpBonus: StreakBonus.getBonus(newStreak),
      milestoneMessage: StreakBonus.getMilestoneMessage(newStreak),
      streakBroken: streakBroken,
    );
  }
}
