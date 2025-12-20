import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'notification_settings.dart';

/// Service for handling local notifications
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification IDs
  static const _dailyPuzzleId = 1;
  static const _studyReminderId = 2;
  static const _streakWarningId = 3;
  static const _weeklyDigestId = 4;

  /// Android notification channel
  static const _androidChannel = AndroidNotificationChannel(
    'chess_mastery_reminders',
    'Chess Mastery Reminders',
    description: 'Reminders for puzzles, study, and streaks',
    importance: Importance.high,
  );

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Handle navigation based on payload
      // e.g., 'daily_puzzle' -> navigate to puzzle screen
      debugPrint('Notification tapped with payload: $payload');
    }
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    if (Platform.isAndroid) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }

    return true;
  }

  /// Schedule all notifications based on settings
  Future<void> scheduleAllNotifications(NotificationSettings settings) async {
    if (!settings.notificationsEnabled) {
      await cancelAllNotifications();
      return;
    }

    // Daily puzzle
    if (settings.dailyPuzzleEnabled) {
      await scheduleDailyPuzzleReminder(settings.dailyPuzzleTime);
    } else {
      await cancelNotification(_dailyPuzzleId);
    }

    // Study reminder
    if (settings.studyReminderEnabled) {
      await scheduleStudyReminder(settings.studyReminderTime);
    } else {
      await cancelNotification(_studyReminderId);
    }

    // Streak warning
    if (settings.streakWarningEnabled) {
      await scheduleStreakWarning(settings.streakWarningTime);
    } else {
      await cancelNotification(_streakWarningId);
    }

    // Weekly digest
    if (settings.weeklyDigestEnabled) {
      await scheduleWeeklyDigest();
    } else {
      await cancelNotification(_weeklyDigestId);
    }
  }

  /// Schedule daily puzzle reminder
  Future<void> scheduleDailyPuzzleReminder(TimeOfDay time) async {
    await _scheduleDaily(
      id: _dailyPuzzleId,
      time: time,
      title: '🧩 Daily Puzzle Ready!',
      body: 'Your daily chess puzzle is waiting. Keep your streak going!',
      payload: 'daily_puzzle',
    );
  }

  /// Schedule study reminder
  Future<void> scheduleStudyReminder(TimeOfDay time) async {
    await _scheduleDaily(
      id: _studyReminderId,
      time: time,
      title: '📚 Time to Study!',
      body: 'Practice makes perfect. Review some chess boards today.',
      payload: 'study_reminder',
    );
  }

  /// Schedule streak warning
  Future<void> scheduleStreakWarning(TimeOfDay time) async {
    await _scheduleDaily(
      id: _streakWarningId,
      time: time,
      title: '🔥 Don\'t Lose Your Streak!',
      body: 'Complete a puzzle or study session to keep your streak alive.',
      payload: 'streak_warning',
    );
  }

  /// Schedule weekly digest (Sunday 10 AM)
  Future<void> scheduleWeeklyDigest() async {
    await _scheduleWeekly(
      id: _weeklyDigestId,
      dayOfWeek: DateTime.sunday,
      time: const TimeOfDay(hour: 10, minute: 0),
      title: '📊 Your Weekly Chess Summary',
      body: 'See your progress this week!',
      payload: 'weekly_digest',
    );
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chess_mastery_reminders',
      'Chess Mastery Reminders',
      channelDescription: 'Reminders for puzzles, study, and streaks',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Show analysis complete notification
  Future<void> showAnalysisComplete({
    required String gameId,
    required double accuracy,
  }) async {
    await showNotification(
      id: 100, // Use a unique ID for analysis notifications
      title: '✅ Analysis Complete',
      body: 'Your game analysis is ready. Accuracy: ${accuracy.toStringAsFixed(1)}%',
      payload: 'game_review:$gameId',
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel streak warning for today (call when user completes an activity)
  Future<void> cancelTodaysStreakWarning() async {
    await cancelNotification(_streakWarningId);
    // Reschedule for tomorrow
    // (Will be rescheduled on next app open via scheduleAllNotifications)
  }

  // ============ Private Helpers ============

  /// Schedule a daily notification at a specific time
  Future<void> _scheduleDaily({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
    String? payload,
  }) async {
    final scheduledTime = _nextInstanceOfTime(time);

    const androidDetails = AndroidNotificationDetails(
      'chess_mastery_reminders',
      'Chess Mastery Reminders',
      channelDescription: 'Reminders for puzzles, study, and streaks',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: payload,
    );
  }

  /// Schedule a weekly notification
  Future<void> _scheduleWeekly({
    required int id,
    required int dayOfWeek,
    required TimeOfDay time,
    required String title,
    required String body,
    String? payload,
  }) async {
    final scheduledTime = _nextInstanceOfWeekday(dayOfWeek, time);

    const androidDetails = AndroidNotificationDetails(
      'chess_mastery_reminders',
      'Chess Mastery Reminders',
      channelDescription: 'Reminders for puzzles, study, and streaks',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
      payload: payload,
    );
  }

  /// Get next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Get next instance of a specific weekday and time
  tz.TZDateTime _nextInstanceOfWeekday(int dayOfWeek, TimeOfDay time) {
    var scheduled = _nextInstanceOfTime(time);

    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
