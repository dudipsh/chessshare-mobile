import 'package:flutter/material.dart';

import '../services/force_update_service.dart';

/// Dialog shown when a force update is required
/// This dialog cannot be dismissed - user must update
class ForceUpdateDialog extends StatelessWidget {
  final UpdateCheckResult result;
  final bool isForced;

  const ForceUpdateDialog({
    super.key,
    required this.result,
    this.isForced = true,
  });

  /// Show force update dialog (cannot be dismissed)
  static Future<void> showForceUpdate(BuildContext context, UpdateCheckResult result) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: ForceUpdateDialog(result: result, isForced: true),
      ),
    );
  }

  /// Show optional update dialog (can be dismissed)
  static Future<bool?> showOptionalUpdate(BuildContext context, UpdateCheckResult result) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ForceUpdateDialog(result: result, isForced: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isForced
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isForced ? Icons.system_update : Icons.update,
              size: 36,
              color: isForced ? Colors.orange : Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            isForced ? 'נדרש עדכון' : 'עדכון זמין',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Message
          Text(
            result.message ?? 'גרסה חדשה זמינה. אנא עדכן כדי להמשיך.',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Version info
          Text(
            'גרסה נוכחית: ${result.currentVersion}\nגרסה חדשה: ${result.latestVersion}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Update button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ForceUpdateService.openStore(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isForced ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'עדכן עכשיו',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Later button (only for optional updates)
          if (!isForced) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'אחר כך',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
