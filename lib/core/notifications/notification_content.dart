import 'notification_types.dart';

/// Holds the title and body for a notification
class NotificationContent {
  final String title;
  final String body;

  const NotificationContent({
    required this.title,
    required this.body,
  });
}

/// Provider for notification content
/// Centralized place to manage all notification messages
/// Easy to modify or localize
abstract class NotificationContentProvider {
  /// Get content for a notification type with optional context data
  static NotificationContent getContent(
    NotificationType type, {
    Map<String, dynamic>? data,
  }) {
    switch (type) {
      case NotificationType.dailyPuzzle:
        return _getDailyPuzzleContent(data);
      case NotificationType.gamePuzzles:
        return _getGamePuzzlesContent(data);
      case NotificationType.streakWarning:
        return _getStreakWarningContent(data);
      case NotificationType.studyReminder:
        return _getStudyReminderContent(data);
      case NotificationType.weeklyDigest:
        return _getWeeklyDigestContent(data);
    }
  }

  /// Get test content for a notification type
  static NotificationContent getTestContent(NotificationType type) {
    switch (type) {
      case NotificationType.dailyPuzzle:
        return const NotificationContent(
          title: 'Test: Daily Puzzle',
          body: 'This is how your daily puzzle reminder will look!',
        );
      case NotificationType.gamePuzzles:
        return const NotificationContent(
          title: 'Test: Game Puzzles',
          body: 'You have 5 puzzles from your games waiting!',
        );
      case NotificationType.streakWarning:
        return const NotificationContent(
          title: 'Test: Streak Warning',
          body: 'Your 7-day streak is at risk! Complete a puzzle now.',
        );
      case NotificationType.studyReminder:
        return const NotificationContent(
          title: 'Test: Study Reminder',
          body: 'Time to practice your chess openings!',
        );
      case NotificationType.weeklyDigest:
        return const NotificationContent(
          title: 'Test: Weekly Summary',
          body: 'This week: 15 puzzles solved, 3 games analyzed, 78% accuracy!',
        );
    }
  }

  // ============ Private Content Generators ============

  static NotificationContent _getDailyPuzzleContent(Map<String, dynamic>? data) {
    final streakDays = data?['streakDays'] as int? ?? 0;

    if (streakDays > 0) {
      return NotificationContent(
        title: 'Daily Puzzle Awaits!',
        body: 'Keep your $streakDays-day streak going. Solve today\'s puzzle!',
      );
    }

    return const NotificationContent(
      title: 'Daily Puzzle Ready!',
      body: 'Challenge yourself with today\'s puzzle!',
    );
  }

  static NotificationContent _getGamePuzzlesContent(Map<String, dynamic>? data) {
    final count = data?['unsolvedCount'] as int? ?? 0;
    final opponentName = data?['lastOpponent'] as String?;

    if (count == 1 && opponentName != null) {
      return NotificationContent(
        title: 'Practice Your Mistake',
        body: 'A puzzle from your game against $opponentName is waiting!',
      );
    }

    if (count > 0) {
      return NotificationContent(
        title: 'Practice Your Mistakes',
        body: 'You have $count puzzle${count > 1 ? 's' : ''} from your games. Turn mistakes into mastery!',
      );
    }

    return const NotificationContent(
      title: 'Review Your Games',
      body: 'Analyze a game to generate practice puzzles!',
    );
  }

  static NotificationContent _getStreakWarningContent(Map<String, dynamic>? data) {
    final streakDays = data?['streakDays'] as int? ?? 0;

    if (streakDays > 7) {
      return NotificationContent(
        title: 'Don\'t Break Your Amazing Streak!',
        body: 'You\'re on a $streakDays-day streak! Complete a puzzle to keep it alive.',
      );
    }

    if (streakDays > 0) {
      return NotificationContent(
        title: 'Your Streak is at Risk!',
        body: 'Complete a puzzle to keep your $streakDays-day streak alive!',
      );
    }

    return const NotificationContent(
      title: 'Start a Streak Today!',
      body: 'Complete a puzzle to begin your streak!',
    );
  }

  static NotificationContent _getStudyReminderContent(Map<String, dynamic>? data) {
    final boardsCount = data?['boardsCount'] as int? ?? 0;
    final lastStudyDays = data?['daysSinceLastStudy'] as int? ?? 0;

    if (lastStudyDays > 7) {
      return const NotificationContent(
        title: 'Time to Get Back to Study!',
        body: 'It\'s been a while. Review your openings to stay sharp!',
      );
    }

    if (boardsCount > 0) {
      return NotificationContent(
        title: 'Time to Study!',
        body: 'You have $boardsCount board${boardsCount > 1 ? 's' : ''} to practice. Keep improving!',
      );
    }

    return const NotificationContent(
      title: 'Study Time!',
      body: 'Practice makes perfect. Review some chess positions today.',
    );
  }

  static NotificationContent _getWeeklyDigestContent(Map<String, dynamic>? data) {
    final puzzlesSolved = data?['puzzlesSolved'] as int? ?? 0;
    final gamesAnalyzed = data?['gamesAnalyzed'] as int? ?? 0;
    final avgAccuracy = data?['avgAccuracy'] as double?;

    final parts = <String>[];
    if (puzzlesSolved > 0) parts.add('$puzzlesSolved puzzles');
    if (gamesAnalyzed > 0) parts.add('$gamesAnalyzed games');
    if (avgAccuracy != null) parts.add('${avgAccuracy.toStringAsFixed(0)}% accuracy');

    if (parts.isNotEmpty) {
      return NotificationContent(
        title: 'Your Weekly Chess Journey',
        body: 'This week: ${parts.join(', ')}. Keep it up!',
      );
    }

    return const NotificationContent(
      title: 'Weekly Chess Summary',
      body: 'See your progress this week!',
    );
  }
}
