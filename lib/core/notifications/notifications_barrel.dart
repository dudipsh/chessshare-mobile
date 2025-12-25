/// Local Notifications System
///
/// Modular notification system with easy extensibility.
///
/// To add a new notification type:
/// 1. Add enum value in notification_types.dart
/// 2. Add content in notification_content.dart
/// 3. Settings are automatically handled
///
/// Example usage:
/// ```dart
/// // Toggle a specific notification type
/// ref.read(notificationProvider.notifier).toggleType(NotificationType.dailyPuzzle, true);
///
/// // Set time for a type
/// ref.read(notificationProvider.notifier).setTypeTime(
///   NotificationType.dailyPuzzle,
///   TimeOfDay(hour: 9, minute: 0),
/// );
///
/// // Test a notification
/// ref.read(notificationProvider.notifier).showTestNotification(NotificationType.dailyPuzzle);
/// ```

export 'local_notification_service.dart';
export 'notification_content.dart';
export 'notification_navigation.dart';
export 'notification_provider.dart';
export 'notification_settings.dart';
export 'notification_types.dart';
