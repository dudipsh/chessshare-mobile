import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types of notifications
enum NotificationType {
  dailyPuzzle('daily_puzzle', 'Daily Puzzle'),
  studyReminder('study_reminder', 'Study Reminder'),
  streakWarning('streak_warning', 'Streak Warning'),
  weeklyDigest('weekly_digest', 'Weekly Summary');

  final String code;
  final String displayName;

  const NotificationType(this.code, this.displayName);
}

/// User notification preferences
class NotificationSettings {
  /// Daily puzzle reminder
  final bool dailyPuzzleEnabled;
  final TimeOfDay dailyPuzzleTime;

  /// Study reminder
  final bool studyReminderEnabled;
  final TimeOfDay studyReminderTime;

  /// Streak warning (sent in evening if user hasn't logged in)
  final bool streakWarningEnabled;
  final TimeOfDay streakWarningTime;

  /// Weekly digest
  final bool weeklyDigestEnabled;

  /// Master switch
  final bool notificationsEnabled;

  /// Smart dismissal tracking
  final int dailyPuzzleIgnoreCount;
  final int studyReminderIgnoreCount;
  final int streakWarningIgnoreCount;
  final bool smartDismissalEnabled;
  final DateTime? lastNotificationDate;
  final DateTime? lastAppOpenDate;

  /// Whether user has been shown the "we understand" message
  final bool shownDismissalMessage;

  const NotificationSettings({
    this.dailyPuzzleEnabled = true,
    this.dailyPuzzleTime = const TimeOfDay(hour: 9, minute: 0),
    this.studyReminderEnabled = true,
    this.studyReminderTime = const TimeOfDay(hour: 19, minute: 0),
    this.streakWarningEnabled = true,
    this.streakWarningTime = const TimeOfDay(hour: 20, minute: 0),
    this.weeklyDigestEnabled = true,
    this.notificationsEnabled = true,
    this.dailyPuzzleIgnoreCount = 0,
    this.studyReminderIgnoreCount = 0,
    this.streakWarningIgnoreCount = 0,
    this.smartDismissalEnabled = true,
    this.lastNotificationDate,
    this.lastAppOpenDate,
    this.shownDismissalMessage = false,
  });

  NotificationSettings copyWith({
    bool? dailyPuzzleEnabled,
    TimeOfDay? dailyPuzzleTime,
    bool? studyReminderEnabled,
    TimeOfDay? studyReminderTime,
    bool? streakWarningEnabled,
    TimeOfDay? streakWarningTime,
    bool? weeklyDigestEnabled,
    bool? notificationsEnabled,
    int? dailyPuzzleIgnoreCount,
    int? studyReminderIgnoreCount,
    int? streakWarningIgnoreCount,
    bool? smartDismissalEnabled,
    DateTime? lastNotificationDate,
    DateTime? lastAppOpenDate,
    bool? shownDismissalMessage,
  }) {
    return NotificationSettings(
      dailyPuzzleEnabled: dailyPuzzleEnabled ?? this.dailyPuzzleEnabled,
      dailyPuzzleTime: dailyPuzzleTime ?? this.dailyPuzzleTime,
      studyReminderEnabled: studyReminderEnabled ?? this.studyReminderEnabled,
      studyReminderTime: studyReminderTime ?? this.studyReminderTime,
      streakWarningEnabled: streakWarningEnabled ?? this.streakWarningEnabled,
      streakWarningTime: streakWarningTime ?? this.streakWarningTime,
      weeklyDigestEnabled: weeklyDigestEnabled ?? this.weeklyDigestEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyPuzzleIgnoreCount: dailyPuzzleIgnoreCount ?? this.dailyPuzzleIgnoreCount,
      studyReminderIgnoreCount: studyReminderIgnoreCount ?? this.studyReminderIgnoreCount,
      streakWarningIgnoreCount: streakWarningIgnoreCount ?? this.streakWarningIgnoreCount,
      smartDismissalEnabled: smartDismissalEnabled ?? this.smartDismissalEnabled,
      lastNotificationDate: lastNotificationDate ?? this.lastNotificationDate,
      lastAppOpenDate: lastAppOpenDate ?? this.lastAppOpenDate,
      shownDismissalMessage: shownDismissalMessage ?? this.shownDismissalMessage,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'dailyPuzzleEnabled': dailyPuzzleEnabled,
      'dailyPuzzleTime': {'hour': dailyPuzzleTime.hour, 'minute': dailyPuzzleTime.minute},
      'studyReminderEnabled': studyReminderEnabled,
      'studyReminderTime': {'hour': studyReminderTime.hour, 'minute': studyReminderTime.minute},
      'streakWarningEnabled': streakWarningEnabled,
      'streakWarningTime': {'hour': streakWarningTime.hour, 'minute': streakWarningTime.minute},
      'weeklyDigestEnabled': weeklyDigestEnabled,
      'notificationsEnabled': notificationsEnabled,
      'dailyPuzzleIgnoreCount': dailyPuzzleIgnoreCount,
      'studyReminderIgnoreCount': studyReminderIgnoreCount,
      'streakWarningIgnoreCount': streakWarningIgnoreCount,
      'smartDismissalEnabled': smartDismissalEnabled,
      'lastNotificationDate': lastNotificationDate?.toIso8601String(),
      'lastAppOpenDate': lastAppOpenDate?.toIso8601String(),
      'shownDismissalMessage': shownDismissalMessage,
    };
  }

  /// Create from JSON
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      dailyPuzzleEnabled: json['dailyPuzzleEnabled'] as bool? ?? true,
      dailyPuzzleTime: _parseTimeOfDay(json['dailyPuzzleTime']) ?? const TimeOfDay(hour: 9, minute: 0),
      studyReminderEnabled: json['studyReminderEnabled'] as bool? ?? true,
      studyReminderTime: _parseTimeOfDay(json['studyReminderTime']) ?? const TimeOfDay(hour: 19, minute: 0),
      streakWarningEnabled: json['streakWarningEnabled'] as bool? ?? true,
      streakWarningTime: _parseTimeOfDay(json['streakWarningTime']) ?? const TimeOfDay(hour: 20, minute: 0),
      weeklyDigestEnabled: json['weeklyDigestEnabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      dailyPuzzleIgnoreCount: json['dailyPuzzleIgnoreCount'] as int? ?? 0,
      studyReminderIgnoreCount: json['studyReminderIgnoreCount'] as int? ?? 0,
      streakWarningIgnoreCount: json['streakWarningIgnoreCount'] as int? ?? 0,
      smartDismissalEnabled: json['smartDismissalEnabled'] as bool? ?? true,
      lastNotificationDate: _parseDateTime(json['lastNotificationDate']),
      lastAppOpenDate: _parseDateTime(json['lastAppOpenDate']),
      shownDismissalMessage: json['shownDismissalMessage'] as bool? ?? false,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static TimeOfDay? _parseTimeOfDay(dynamic value) {
    if (value is Map) {
      final hour = value['hour'] as int?;
      final minute = value['minute'] as int?;
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }
}

/// Repository for notification settings
class NotificationSettingsRepository {
  static const _key = 'notification_settings';

  /// Load settings from local storage
  Future<NotificationSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return NotificationSettings.fromJson(json);
      }
    } catch (e) {
      print('NotificationSettingsRepository: Error loading settings: $e');
    }

    return const NotificationSettings();
  }

  /// Save settings to local storage
  Future<void> saveSettings(NotificationSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(_key, jsonString);
    } catch (e) {
      print('NotificationSettingsRepository: Error saving settings: $e');
    }
  }
}
