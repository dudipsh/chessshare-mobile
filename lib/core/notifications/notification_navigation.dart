import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'notification_types.dart';

/// Service to handle notification tap navigation
class NotificationNavigationService {
  static final NotificationNavigationService _instance =
      NotificationNavigationService._internal();
  factory NotificationNavigationService() => _instance;
  NotificationNavigationService._internal();

  /// Stream controller for notification taps
  final _navigationController = StreamController<String>.broadcast();

  /// Stream of notification payloads to navigate to
  Stream<String> get navigationStream => _navigationController.stream;

  /// Pending payload from cold start
  String? _pendingPayload;

  /// Set pending payload (for cold starts)
  set pendingPayload(String? payload) => _pendingPayload = payload;

  /// Get and clear pending payload
  String? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  /// Called when a notification is tapped
  void onNotificationTapped(String payload) {
    debugPrint('NotificationNavigationService: tapped with payload: $payload');
    debugPrint('NotificationNavigationService: stream has listeners: ${_navigationController.hasListener}');
    _navigationController.add(payload);
  }

  /// Navigate based on payload
  static void navigateFromPayload(BuildContext context, String payload) {
    debugPrint('navigateFromPayload called with: $payload');

    // Remove 'test_' prefix if present
    final cleanPayload = payload.startsWith('test_')
        ? payload.substring(5)
        : payload;

    debugPrint('Clean payload: $cleanPayload');

    final type = NotificationType.fromCode(cleanPayload);
    if (type != null) {
      debugPrint('Navigating to ${type.route} for ${type.displayName}');
      context.go(type.route);
    } else {
      debugPrint('Unknown notification payload: $payload');
    }
  }

  void dispose() {
    _navigationController.close();
  }
}
