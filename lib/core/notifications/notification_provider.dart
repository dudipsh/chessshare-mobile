import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notification_service.dart';
import 'notification_settings.dart';
import 'notification_types.dart';

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
    required this.settings,
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

  /// Max ignores before we disable notifications
  static const int _maxIgnoreCount = 3;

  NotificationNotifier(this._repository, this._service)
      : super(NotificationState(
          settings: NotificationSettings.defaults(),
          isLoading: true,
        )) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      var settings = await _repository.loadSettings();
      final permissionGranted = await _service.requestPermissions();

      settings = await _checkSmartDismissal(settings);

      state = NotificationState(
        settings: settings,
        isLoading: false,
        permissionGranted: permissionGranted,
      );

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

  /// Check if user has been ignoring notifications
  Future<NotificationSettings> _checkSmartDismissal(NotificationSettings settings) async {
    if (!settings.smartDismissalEnabled) return settings;

    final now = DateTime.now();
    var newSettings = settings.copyWith(lastAppOpenDate: now);
    await _repository.saveSettings(newSettings);
    return newSettings;
  }

  /// Update settings and reschedule notifications
  Future<void> updateSettings(NotificationSettings settings) async {
    state = state.copyWith(settings: settings);
    await _repository.saveSettings(settings);

    if (state.permissionGranted) {
      await _service.scheduleAllNotifications(settings);
    }
  }

  /// Toggle master notifications switch
  Future<void> toggleNotifications(bool enabled) async {
    await updateSettings(state.settings.copyWith(notificationsEnabled: enabled));
  }

  /// Toggle a specific notification type
  Future<void> toggleType(NotificationType type, bool enabled) async {
    await updateSettings(state.settings.toggleType(type, enabled));
  }

  /// Set time for a specific notification type
  Future<void> setTypeTime(NotificationType type, TimeOfDay time) async {
    await updateSettings(state.settings.setTypeTime(type, time));
  }

  /// Reset ignore count when user opens via notification
  Future<void> resetIgnoreCount(NotificationType type) async {
    await updateSettings(state.settings.resetIgnoreCount(type));
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

  /// Show test notification for a type
  Future<void> showTestNotification(NotificationType type) async {
    await _service.showTestNotification(type);
  }

  /// Show all test notifications
  Future<void> showAllTestNotifications() async {
    for (final type in NotificationType.values) {
      await _service.showTestNotification(type);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Cancel streak warning (when user completes activity)
  Future<void> cancelStreakWarning() async {
    await _service.cancelTypeNotification(NotificationType.streakWarning);
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
