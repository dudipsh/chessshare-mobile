/// Local Notifications System
///
/// Handles scheduling and managing local notifications for:
/// - Daily puzzle reminders
/// - Study reminders
/// - Streak warnings
/// - Weekly digest
/// - Analysis complete notifications
///
/// Example usage:
/// ```dart
/// // Initialize in main.dart
/// await LocalNotificationService().initialize();
///
/// // Toggle notifications in settings
/// ref.read(notificationProvider.notifier).toggleNotifications(true);
///
/// // Set reminder time
/// ref.read(notificationProvider.notifier).setDailyPuzzleTime(
///   TimeOfDay(hour: 9, minute: 0),
/// );
///
/// // Cancel streak warning when user completes an activity
/// ref.read(notificationProvider.notifier).cancelTodaysStreakWarning();
///
/// // Show analysis complete notification
/// ref.read(notificationProvider.notifier).showAnalysisComplete(
///   gameId: 'abc123',
///   accuracy: 85.5,
/// );
/// ```

export 'notification_settings.dart';
export 'local_notification_service.dart';
export 'notification_provider.dart';
