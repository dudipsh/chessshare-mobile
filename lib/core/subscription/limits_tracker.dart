import 'package:shared_preferences/shared_preferences.dart';

/// Types of actions that can be limited
enum LimitedAction {
  gameAnalysis('game_analysis'),
  boardView('board_view'),
  dailyPuzzle('daily_puzzle'),
  mistakeSave('mistake_save');

  final String key;
  const LimitedAction(this.key);
}

/// Tracks daily usage of limited actions locally
class LimitsTracker {
  static const _prefix = 'limits_';

  /// Get usage count for an action today
  Future<int> getUsageCount(LimitedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(action);
    final stored = prefs.getString(key);

    if (stored == null) return 0;

    // Parse stored value: "date|count"
    final parts = stored.split('|');
    if (parts.length != 2) return 0;

    final storedDate = parts[0];
    final today = _getTodayString();

    // If stored date is not today, reset count
    if (storedDate != today) {
      return 0;
    }

    return int.tryParse(parts[1]) ?? 0;
  }

  /// Increment usage count for an action
  Future<int> recordUsage(LimitedAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(action);
    final today = _getTodayString();

    // Get current count for today
    final currentCount = await getUsageCount(action);
    final newCount = currentCount + 1;

    // Store: "date|count"
    await prefs.setString(key, '$today|$newCount');

    return newCount;
  }

  /// Check if user can perform action (within limit)
  Future<bool> canPerform(LimitedAction action, int limit) async {
    if (limit >= 999999) return true; // Unlimited
    final count = await getUsageCount(action);
    return count < limit;
  }

  /// Get remaining count for an action
  Future<int> getRemainingCount(LimitedAction action, int limit) async {
    if (limit >= 999999) return limit; // Unlimited
    final count = await getUsageCount(action);
    return (limit - count).clamp(0, limit);
  }

  /// Reset all limits (for testing or new day)
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final action in LimitedAction.values) {
      await prefs.remove(_getKey(action));
    }
  }

  /// Get storage key for an action
  String _getKey(LimitedAction action) => '$_prefix${action.key}';

  /// Get today's date as string (YYYY-MM-DD)
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Result of attempting a limited action
class LimitCheckResult {
  final bool allowed;
  final int used;
  final int limit;
  final String? message;

  const LimitCheckResult({
    required this.allowed,
    required this.used,
    required this.limit,
    this.message,
  });

  /// Remaining quota
  int get remaining => (limit - used).clamp(0, limit);

  /// Whether limit is unlimited
  bool get isUnlimited => limit >= 999999;

  /// Friendly message for UI
  String get displayMessage {
    if (allowed) {
      if (isUnlimited) return 'Unlimited';
      return '$remaining remaining today';
    }
    return message ?? 'Daily limit reached. Upgrade to continue.';
  }
}
