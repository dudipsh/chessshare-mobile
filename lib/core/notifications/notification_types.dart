import 'package:flutter/material.dart';

/// All notification types in the app
/// To add a new notification:
/// 1. Add enum value here with metadata
/// 2. Add content in NotificationContent
/// 3. Add settings field in NotificationSettings
/// 4. Add scheduling logic in LocalNotificationService
enum NotificationType {
  dailyPuzzle(
    id: 1,
    code: 'daily_puzzle',
    displayName: 'Daily Puzzle',
    description: 'Get reminded to solve the daily puzzle',
    icon: Icons.extension,
    color: Colors.green,
    defaultHour: 9,
    defaultMinute: 0,
    frequency: NotificationFrequency.daily,
    route: '/daily-puzzle',
  ),
  gamePuzzles(
    id: 2,
    code: 'game_puzzles',
    displayName: 'Game Puzzles',
    description: 'Reminders about puzzles from your analyzed games',
    icon: Icons.sports_esports,
    color: Colors.blue,
    defaultHour: 19,
    defaultMinute: 0,
    frequency: NotificationFrequency.daily,
    route: '/puzzles',
  ),
  streakWarning(
    id: 3,
    code: 'streak_warning',
    displayName: 'Streak Warning',
    description: 'Get warned before losing your streak',
    icon: Icons.local_fire_department,
    color: Colors.orange,
    defaultHour: 20,
    defaultMinute: 0,
    frequency: NotificationFrequency.daily,
    route: '/daily-puzzle',
  ),
  studyReminder(
    id: 4,
    code: 'study_reminder',
    displayName: 'Study Reminder',
    description: 'Get reminded to practice your openings',
    icon: Icons.school,
    color: Colors.indigo,
    defaultHour: 19,
    defaultMinute: 0,
    frequency: NotificationFrequency.daily,
    route: '/study',
  ),
  weeklyDigest(
    id: 5,
    code: 'weekly_digest',
    displayName: 'Weekly Summary',
    description: 'Get a summary of your weekly progress',
    icon: Icons.bar_chart,
    color: Colors.purple,
    defaultHour: 10,
    defaultMinute: 0,
    frequency: NotificationFrequency.weekly,
    route: '/insights',
  );

  final int id;
  final String code;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final int defaultHour;
  final int defaultMinute;
  final NotificationFrequency frequency;
  final String route;

  const NotificationType({
    required this.id,
    required this.code,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultHour,
    required this.defaultMinute,
    required this.frequency,
    required this.route,
  });

  TimeOfDay get defaultTime => TimeOfDay(hour: defaultHour, minute: defaultMinute);

  /// Get type from code string (for payload parsing)
  static NotificationType? fromCode(String code) {
    try {
      return NotificationType.values.firstWhere((t) => t.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get type from notification ID
  static NotificationType? fromId(int id) {
    try {
      return NotificationType.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

enum NotificationFrequency {
  daily,
  weekly,
  once,
}
