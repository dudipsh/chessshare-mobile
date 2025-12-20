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

  const NotificationState({
    this.settings = const NotificationSettings(),
    this.isLoading = false,
    this.permissionGranted = false,
    this.error,
  });

  NotificationState copyWith({
    NotificationSettings? settings,
    bool? isLoading,
    bool? permissionGranted,
    String? error,
  }) {
    return NotificationState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      error: error,
    );
  }
}

/// Notifier for managing notification state
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationSettingsRepository _repository;
  final LocalNotificationService _service;

  NotificationNotifier(this._repository, this._service)
      : super(const NotificationState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize service
      await _service.initialize();

      // Load settings
      final settings = await _repository.loadSettings();

      // Request permissions
      final permissionGranted = await _service.requestPermissions();

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
