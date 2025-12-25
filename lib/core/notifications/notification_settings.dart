import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_types.dart';

/// Settings for a single notification type
class NotificationTypeSettings {
  final bool enabled;
  final TimeOfDay time;
  final int ignoreCount;

  const NotificationTypeSettings({
    this.enabled = true,
    required this.time,
    this.ignoreCount = 0,
  });

  NotificationTypeSettings copyWith({
    bool? enabled,
    TimeOfDay? time,
    int? ignoreCount,
  }) {
    return NotificationTypeSettings(
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
      ignoreCount: ignoreCount ?? this.ignoreCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': time.hour,
        'minute': time.minute,
        'ignoreCount': ignoreCount,
      };

  factory NotificationTypeSettings.fromJson(Map<String, dynamic> json, TimeOfDay defaultTime) {
    return NotificationTypeSettings(
      enabled: json['enabled'] as bool? ?? true,
      time: TimeOfDay(
        hour: json['hour'] as int? ?? defaultTime.hour,
        minute: json['minute'] as int? ?? defaultTime.minute,
      ),
      ignoreCount: json['ignoreCount'] as int? ?? 0,
    );
  }

  factory NotificationTypeSettings.defaultFor(NotificationType type) {
    return NotificationTypeSettings(
      enabled: true,
      time: type.defaultTime,
      ignoreCount: 0,
    );
  }
}

/// User notification preferences
class NotificationSettings {
  /// Master switch
  final bool notificationsEnabled;

  /// Settings per notification type
  final Map<NotificationType, NotificationTypeSettings> typeSettings;

  /// Smart dismissal
  final bool smartDismissalEnabled;
  final DateTime? lastNotificationDate;
  final DateTime? lastAppOpenDate;
  final bool shownDismissalMessage;

  const NotificationSettings({
    this.notificationsEnabled = true,
    this.typeSettings = const {},
    this.smartDismissalEnabled = true,
    this.lastNotificationDate,
    this.lastAppOpenDate,
    this.shownDismissalMessage = false,
  });

  /// Get settings for a specific type (with defaults)
  NotificationTypeSettings getTypeSettings(NotificationType type) {
    return typeSettings[type] ?? NotificationTypeSettings.defaultFor(type);
  }

  /// Check if a specific notification type is enabled
  bool isTypeEnabled(NotificationType type) {
    return notificationsEnabled && getTypeSettings(type).enabled;
  }

  /// Get time for a specific notification type
  TimeOfDay getTypeTime(NotificationType type) {
    return getTypeSettings(type).time;
  }

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    Map<NotificationType, NotificationTypeSettings>? typeSettings,
    bool? smartDismissalEnabled,
    DateTime? lastNotificationDate,
    DateTime? lastAppOpenDate,
    bool? shownDismissalMessage,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      typeSettings: typeSettings ?? this.typeSettings,
      smartDismissalEnabled: smartDismissalEnabled ?? this.smartDismissalEnabled,
      lastNotificationDate: lastNotificationDate ?? this.lastNotificationDate,
      lastAppOpenDate: lastAppOpenDate ?? this.lastAppOpenDate,
      shownDismissalMessage: shownDismissalMessage ?? this.shownDismissalMessage,
    );
  }

  /// Update settings for a specific type
  NotificationSettings updateType(
    NotificationType type,
    NotificationTypeSettings settings,
  ) {
    final newTypeSettings = Map<NotificationType, NotificationTypeSettings>.from(typeSettings);
    newTypeSettings[type] = settings;
    return copyWith(typeSettings: newTypeSettings);
  }

  /// Toggle a specific type on/off
  NotificationSettings toggleType(NotificationType type, bool enabled) {
    final current = getTypeSettings(type);
    return updateType(type, current.copyWith(enabled: enabled));
  }

  /// Set time for a specific type
  NotificationSettings setTypeTime(NotificationType type, TimeOfDay time) {
    final current = getTypeSettings(type);
    return updateType(type, current.copyWith(time: time));
  }

  /// Increment ignore count for a type
  NotificationSettings incrementIgnoreCount(NotificationType type) {
    final current = getTypeSettings(type);
    return updateType(type, current.copyWith(ignoreCount: current.ignoreCount + 1));
  }

  /// Reset ignore count for a type
  NotificationSettings resetIgnoreCount(NotificationType type) {
    final current = getTypeSettings(type);
    return updateType(type, current.copyWith(ignoreCount: 0));
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    final typeSettingsJson = <String, dynamic>{};
    for (final entry in typeSettings.entries) {
      typeSettingsJson[entry.key.code] = entry.value.toJson();
    }

    return {
      'notificationsEnabled': notificationsEnabled,
      'typeSettings': typeSettingsJson,
      'smartDismissalEnabled': smartDismissalEnabled,
      'lastNotificationDate': lastNotificationDate?.toIso8601String(),
      'lastAppOpenDate': lastAppOpenDate?.toIso8601String(),
      'shownDismissalMessage': shownDismissalMessage,
    };
  }

  /// Create from JSON
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final typeSettingsJson = json['typeSettings'] as Map<String, dynamic>? ?? {};
    final typeSettings = <NotificationType, NotificationTypeSettings>{};

    for (final type in NotificationType.values) {
      final typeJson = typeSettingsJson[type.code] as Map<String, dynamic>?;
      if (typeJson != null) {
        typeSettings[type] = NotificationTypeSettings.fromJson(typeJson, type.defaultTime);
      }
    }

    return NotificationSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      typeSettings: typeSettings,
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

  /// Default settings with all types enabled
  factory NotificationSettings.defaults() {
    final typeSettings = <NotificationType, NotificationTypeSettings>{};
    for (final type in NotificationType.values) {
      typeSettings[type] = NotificationTypeSettings.defaultFor(type);
    }
    return NotificationSettings(typeSettings: typeSettings);
  }
}

/// Repository for notification settings
class NotificationSettingsRepository {
  static const _key = 'notification_settings_v2';

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
      // ignore error, return defaults
    }

    return NotificationSettings.defaults();
  }

  /// Save settings to local storage
  Future<void> saveSettings(NotificationSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(_key, jsonString);
    } catch (e) {
      // ignore error
    }
  }
}
