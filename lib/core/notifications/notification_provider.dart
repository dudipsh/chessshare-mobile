import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notification_service.dart';
import 'notification_settings.dart';

/// Provider for the NotificationSettingsRepository
final notificationSettingsRepositoryProvider = Provider<NotificationSettingsRepository>((ref) {
  return NotificationSettingsRepository();
});

/// Provider for the LocalNotificationService
final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

/// State for notification settings
class NotificationState {
  final NotificationSettings settings;
  final bool isLoading;
  final bool permissionGranted;
  final String? error;
  final bool showSmartDismissalDialog;
  final NotificationType? dismissedNotificationType;

  const NotificationState({
    this.settings = const NotificationSettings(),
    this.isLoading = false,
    this.permissionGranted = false,
    this.error,
    this.showSmartDismissalDialog = false,
    this.dismissedNotificationType,
  });

  NotificationState copyWith({
    NotificationSettings? settings,
    bool? isLoading,
    bool? permissionGranted,
    String? error,
    bool? showSmartDismissalDialog,
    NotificationType? dismissedNotificationType,
  }) {
    return NotificationState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      error: error,
      showSmartDismissalDialog: showSmartDismissalDialog ?? this.showSmartDismissalDialog,
      dismissedNotificationType: dismissedNotificationType ?? this.dismissedNotificationType,
    );
  }
}

/// Notifier for managing notification state
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationSettingsRepository _repository;
  final LocalNotificationService _service;

  /// Max ignores before we disable notifications
  static const int _maxIgnoreCount = 3;

  NotificationNotifier(this._repository, this._service)
      : super(const NotificationState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize service
      await _service.initialize();

      // Load settings
      var settings = await _repository.loadSettings();

      // Request permissions
      final permissionGranted = await _service.requestPermissions();

      // Check for ignored notifications (smart dismissal)
      settings = await _checkSmartDismissal(settings);

      state = NotificationState(
        settings: settings,
        isLoading: false,
        permissionGranted: permissionGranted,
      );

      // Schedule notifications if enabled and permitted
      if (permissionGranted && settings.notificationsEnabled) {
        await _service.scheduleAllNotifications(settings);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Check if user has been ignoring notifications and handle smart dismissal
  Future<NotificationSettings> _checkSmartDismissal(NotificationSettings settings) async {
    if (!settings.smartDismissalEnabled) return settings;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastOpen = settings.lastAppOpenDate;
    final lastNotification = settings.lastNotificationDate;

    // Update last app open date
    var newSettings = settings.copyWith(lastAppOpenDate: now);

    // If there was a notification sent and user didn't open the app that day
    if (lastNotification != null && lastOpen != null) {
      final notificationDate = DateTime(
        lastNotification.year,
        lastNotification.month,
        lastNotification.day,
      );
      final lastOpenDate = DateTime(
        lastOpen.year,
        lastOpen.month,
        lastOpen.day,
      );

      // If notification was sent on a day before user opened the app
      // and they're opening the app now (not on the notification day)
      if (notificationDate.isBefore(today) && lastOpenDate.isBefore(notificationDate)) {
        // User ignored the notification - increment ignore count
        final newDailyIgnoreCount = newSettings.dailyPuzzleEnabled
            ? newSettings.dailyPuzzleIgnoreCount + 1
            : newSettings.dailyPuzzleIgnoreCount;

        newSettings = newSettings.copyWith(
          dailyPuzzleIgnoreCount: newDailyIgnoreCount,
        );

        // Check if we've hit the limit
        if (newDailyIgnoreCount >= _maxIgnoreCount && !newSettings.shownDismissalMessage) {
          // Show the dismissal dialog and disable notifications
          newSettings = newSettings.copyWith(
            dailyPuzzleEnabled: false,
            shownDismissalMessage: true,
          );

          state = state.copyWith(
            showSmartDismissalDialog: true,
            dismissedNotificationType: NotificationType.dailyPuzzle,
          );
        }
      }
    }

    // Save updated settings
    await _repository.saveSettings(newSettings);
    return newSettings;
  }

  /// Record that a notification was sent today
  Future<void> recordNotificationSent() async {
    final newSettings = state.settings.copyWith(
      lastNotificationDate: DateTime.now(),
    );
    await updateSettings(newSettings);
  }

  /// Dismiss the smart dismissal dialog
  void dismissSmartDismissalDialog() {
    state = state.copyWith(showSmartDismissalDialog: false);
  }

  /// Re-enable notifications after smart dismissal
  Future<void> reEnableNotifications(NotificationType type) async {
    NotificationSettings newSettings;
    switch (type) {
      case NotificationType.dailyPuzzle:
        newSettings = state.settings.copyWith(
          dailyPuzzleEnabled: true,
          dailyPuzzleIgnoreCount: 0,
          shownDismissalMessage: false,
        );
        break;
      case NotificationType.studyReminder:
        newSettings = state.settings.copyWith(
          studyReminderEnabled: true,
          studyReminderIgnoreCount: 0,
        );
        break;
      case NotificationType.streakWarning:
        newSettings = state.settings.copyWith(
          streakWarningEnabled: true,
          streakWarningIgnoreCount: 0,
        );
        break;
      case NotificationType.weeklyDigest:
        newSettings = state.settings.copyWith(weeklyDigestEnabled: true);
        break;
    }
    await updateSettings(newSettings);
  }

  /// Reset ignore count when user opens via notification
  Future<void> resetIgnoreCount(NotificationType type) async {
    NotificationSettings newSettings;
    switch (type) {
      case NotificationType.dailyPuzzle:
        newSettings = state.settings.copyWith(dailyPuzzleIgnoreCount: 0);
        break;
      case NotificationType.studyReminder:
        newSettings = state.settings.copyWith(studyReminderIgnoreCount: 0);
        break;
      case NotificationType.streakWarning:
        newSettings = state.settings.copyWith(streakWarningIgnoreCount: 0);
        break;
      case NotificationType.weeklyDigest:
        newSettings = state.settings;
        break;
    }
    await updateSettings(newSettings);
  }

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings settings) async {
    state = state.copyWith(settings: settings);

    // Save to storage
    await _repository.saveSettings(settings);

    // Reschedule notifications
    if (state.permissionGranted) {
      await _service.scheduleAllNotifications(settings);
    }
  }

  /// Toggle master notifications switch
  Future<void> toggleNotifications(bool enabled) async {
    final newSettings = state.settings.copyWith(notificationsEnabled: enabled);
    await updateSettings(newSettings);
  }

  /// Toggle daily puzzle reminder
  Future<void> toggleDailyPuzzle(bool enabled) async {
    final newSettings = state.settings.copyWith(dailyPuzzleEnabled: enabled);
    await updateSettings(newSettings);
  }

  /// Set daily puzzle time
  Future<void> setDailyPuzzleTime(TimeOfDay time) async {
    final newSettings = state.settings.copyWith(dailyPuzzleTime: time);
    await updateSettings(newSettings);
  }

  /// Toggle study reminder
  Future<void> toggleStudyReminder(bool enabled) async {
    final newSettings = state.settings.copyWith(studyReminderEnabled: enabled);
    await updateSettings(newSettings);
  }

  /// Set study reminder time
  Future<void> setStudyReminderTime(TimeOfDay time) async {
    final newSettings = state.settings.copyWith(studyReminderTime: time);
    await updateSettings(newSettings);
  }

  /// Toggle streak warning
  Future<void> toggleStreakWarning(bool enabled) async {
    final newSettings = state.settings.copyWith(streakWarningEnabled: enabled);
    await updateSettings(newSettings);
  }

  /// Set streak warning time
  Future<void> setStreakWarningTime(TimeOfDay time) async {
    final newSettings = state.settings.copyWith(streakWarningTime: time);
    await updateSettings(newSettings);
  }

  /// Toggle weekly digest
  Future<void> toggleWeeklyDigest(bool enabled) async {
    final newSettings = state.settings.copyWith(weeklyDigestEnabled: enabled);
    await updateSettings(newSettings);
  }

  /// Show analysis complete notification
  Future<void> showAnalysisComplete({
    required String gameId,
    required double accuracy,
  }) async {
    if (!state.settings.notificationsEnabled) return;

    await _service.showAnalysisComplete(
      gameId: gameId,
      accuracy: accuracy,
    );
  }

  /// Cancel streak warning for today
  Future<void> cancelTodaysStreakWarning() async {
    await _service.cancelTodaysStreakWarning();
  }

  /// Request permissions again
  Future<bool> requestPermissions() async {
    final granted = await _service.requestPermissions();
    state = state.copyWith(permissionGranted: granted);

    if (granted && state.settings.notificationsEnabled) {
      await _service.scheduleAllNotifications(state.settings);
    }

    return granted;
  }
}

/// Provider for notification state
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final repository = ref.watch(notificationSettingsRepositoryProvider);
  final service = ref.watch(localNotificationServiceProvider);
  return NotificationNotifier(repository, service);
});

/// Provider for checking if notifications are enabled
final notificationsEnabledProvider = Provider<bool>((ref) {
  final state = ref.watch(notificationProvider);
  return state.settings.notificationsEnabled && state.permissionGranted;
});
