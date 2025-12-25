import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_content.dart';
import 'notification_settings.dart';
import 'notification_types.dart';

/// Service for handling local notifications
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Android notification channels
  static const _highPriorityChannel = AndroidNotificationChannel(
    'chess_reminders_high',
    'Chess Reminders',
    description: 'Important chess reminders like daily puzzles and streaks',
    importance: Importance.high,
  );

  static const _defaultChannel = AndroidNotificationChannel(
    'chess_reminders_default',
    'Chess Updates',
    description: 'Weekly summaries and game puzzle reminders',
    importance: Importance.defaultImportance,
  );

  /// Callback for notification taps - set by the app
  static void Function(String payload)? onNotificationTap;

  /// Payload from app launch (cold start)
  static String? launchPayload;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS/macOS settings with foreground presentation
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

    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_highPriorityChannel);
      await androidPlugin?.createNotificationChannel(_defaultChannel);
    }

    // Check if app was launched from notification (cold start)
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null) {
        debugPrint('App launched from notification with payload: $payload');
        launchPayload = payload;
      }
    }

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('Notification tapped: $payload');
      onNotificationTap?.call(payload);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }

    return true;
  }

  // ============ Scheduling Methods ============

  /// Schedule all notifications based on settings
  Future<void> scheduleAllNotifications(NotificationSettings settings) async {
    if (!settings.notificationsEnabled) {
      await cancelAllNotifications();
      return;
    }

    for (final type in NotificationType.values) {
      if (settings.isTypeEnabled(type)) {
        await scheduleNotification(type, settings.getTypeTime(type));
      } else {
        await cancelNotification(type.id);
      }
    }
  }

  /// Schedule a notification by type
  Future<void> scheduleNotification(
    NotificationType type,
    TimeOfDay time, {
    Map<String, dynamic>? data,
  }) async {
    final content = NotificationContentProvider.getContent(type, data: data);

    switch (type.frequency) {
      case NotificationFrequency.daily:
        await _scheduleDaily(
          type: type,
          time: time,
          title: content.title,
          body: content.body,
        );
        break;
      case NotificationFrequency.weekly:
        await _scheduleWeekly(
          type: type,
          dayOfWeek: DateTime.sunday,
          time: time,
          title: content.title,
          body: content.body,
        );
        break;
      case NotificationFrequency.once:
        // For one-time notifications, schedule for next occurrence
        await _scheduleOnce(
          type: type,
          scheduledTime: _nextInstanceOfTime(time),
          title: content.title,
          body: content.body,
        );
        break;
    }
  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool highPriority = false,
  }) async {
    final details = _getNotificationDetails(highPriority: highPriority);
    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Show immediate notification for a type
  Future<void> showTypeNotification(
    NotificationType type, {
    Map<String, dynamic>? data,
  }) async {
    final content = NotificationContentProvider.getContent(type, data: data);
    final highPriority = type == NotificationType.dailyPuzzle ||
        type == NotificationType.streakWarning;

    await showNotification(
      id: type.id + 100, // Offset to avoid conflict with scheduled
      title: content.title,
      body: content.body,
      payload: type.code,
      highPriority: highPriority,
    );
  }

  /// Show test notification for a type
  Future<void> showTestNotification(NotificationType type) async {
    final content = NotificationContentProvider.getTestContent(type);
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: content.title,
      body: content.body,
      payload: 'test_${type.code}',
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel notification by type
  Future<void> cancelTypeNotification(NotificationType type) async {
    await cancelNotification(type.id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // ============ Private Helpers ============

  NotificationDetails _getNotificationDetails({bool highPriority = false}) {
    final channel = highPriority ? _highPriorityChannel : _defaultChannel;

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: highPriority ? Priority.high : Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,  // iOS 14+ banner
      presentList: true,    // Show in notification center
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Future<void> _scheduleDaily({
    required NotificationType type,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final scheduledTime = _nextInstanceOfTime(time);
    final highPriority = type == NotificationType.dailyPuzzle ||
        type == NotificationType.streakWarning;

    await _notifications.zonedSchedule(
      type.id,
      title,
      body,
      scheduledTime,
      _getNotificationDetails(highPriority: highPriority),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: type.code,
    );
  }

  Future<void> _scheduleWeekly({
    required NotificationType type,
    required int dayOfWeek,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final scheduledTime = _nextInstanceOfWeekday(dayOfWeek, time);

    await _notifications.zonedSchedule(
      type.id,
      title,
      body,
      scheduledTime,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: type.code,
    );
  }

  Future<void> _scheduleOnce({
    required NotificationType type,
    required tz.TZDateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    await _notifications.zonedSchedule(
      type.id,
      title,
      body,
      scheduledTime,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: type.code,
    );
  }

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

  tz.TZDateTime _nextInstanceOfWeekday(int dayOfWeek, TimeOfDay time) {
    var scheduled = _nextInstanceOfTime(time);

    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
