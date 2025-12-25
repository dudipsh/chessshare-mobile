import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_provider.dart';
import '../../../../core/notifications/notification_settings.dart';
import '../../../../core/notifications/notification_types.dart';

void showNotificationSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _NotificationSettingsContent(
        scrollController: scrollController,
      ),
    ),
  );
}

class _NotificationSettingsContent extends ConsumerWidget {
  final ScrollController scrollController;

  const _NotificationSettingsContent({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final settings = state.settings;
    final notifier = ref.read(notificationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildHandle(isDark),
          _buildHeader(isDark),
          const SizedBox(height: 8),

          // Permission banner
          if (!state.permissionGranted) _buildPermissionBanner(context, ref),

          // Master toggle
          _buildMasterToggle(context, settings, notifier),
          const Divider(height: 32),

          // Build section for each notification type
          ...NotificationType.values.map((type) => _buildTypeSection(
                context: context,
                ref: ref,
                type: type,
                settings: settings,
                notifier: notifier,
                isDark: isDark,
              )),

          const SizedBox(height: 24),

          // Test all button
          if (settings.notificationsEnabled && state.permissionGranted)
            _buildTestAllButton(context, notifier),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[600] : Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.notifications,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 12),
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications Disabled',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enable in device settings to receive reminders.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(notificationProvider.notifier).requestPermissions(),
                  child: const Text('Enable'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterToggle(
    BuildContext context,
    NotificationSettings settings,
    NotificationNotifier notifier,
  ) {
    return SwitchListTile(
      title: const Text(
        'Enable Notifications',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        settings.notificationsEnabled
            ? 'Receive chess reminders'
            : 'All notifications disabled',
      ),
      value: settings.notificationsEnabled,
      onChanged: (v) => notifier.toggleNotifications(v),
    );
  }

  Widget _buildTypeSection({
    required BuildContext context,
    required WidgetRef ref,
    required NotificationType type,
    required NotificationSettings settings,
    required NotificationNotifier notifier,
    required bool isDark,
  }) {
    final typeSettings = settings.getTypeSettings(type);
    final isDisabled = !settings.notificationsEnabled;
    final isWeekly = type.frequency == NotificationFrequency.weekly;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: type.color.withValues(alpha: 0.2),
              child: Icon(type.icon, color: type.color, size: 20),
            ),
            title: Text(type.displayName),
            subtitle: Text(
              type.description,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Switch(
              value: typeSettings.enabled,
              onChanged: isDisabled ? null : (v) => notifier.toggleType(type, v),
            ),
          ),
          if (typeSettings.enabled && settings.notificationsEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    isWeekly ? Icons.calendar_today : Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  if (isWeekly)
                    Text(
                      'Every Sunday at ${_formatTime(typeSettings.time)}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () => _selectTime(
                        context,
                        typeSettings.time,
                        (t) => notifier.setTypeTime(type, t),
                      ),
                      child: Text(
                        _formatTime(typeSettings.time),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _testNotification(context, type, notifier),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Test'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTestAllButton(BuildContext context, NotificationNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          await notifier.showAllTestNotifications();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${NotificationType.values.length} test notifications sent'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        icon: const Icon(Icons.bug_report),
        label: const Text('Test All Notifications'),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay currentTime,
    void Function(TimeOfDay) onTimeChange,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (selected != null) {
      onTimeChange(selected);
    }
  }

  Future<void> _testNotification(
    BuildContext context,
    NotificationType type,
    NotificationNotifier notifier,
  ) async {
    await notifier.showTestNotification(type);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test: ${type.displayName} sent'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
