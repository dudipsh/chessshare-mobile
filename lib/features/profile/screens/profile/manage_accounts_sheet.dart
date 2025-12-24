import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../games/providers/games_provider.dart';
import '../../providers/profile_provider.dart';
import 'link_account_sheet.dart';

void showManageAccountsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const ManageAccountsSheet(),
  );
}

class ManageAccountsSheet extends ConsumerWidget {
  const ManageAccountsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chessComUsername = profile?.chessComUsername;
    final lichessUsername = profile?.lichessUsername;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Linked Accounts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chess.com account
          _AccountTile(
            platform: 'chesscom',
            platformName: 'Chess.com',
            username: chessComUsername,
            icon: '♜',
            iconBgColor: const Color(0xFF769656),
            isDark: isDark,
            onEdit: () {
              Navigator.pop(context);
              showLinkAccountSheet(context, ref, platform: 'chesscom');
            },
            onDelete: chessComUsername != null
                ? () => _confirmUnlink(
                      context,
                      ref,
                      'Chess.com',
                      chessComUsername,
                      () => ref.read(authProvider.notifier).unlinkChessComAccount(),
                    )
                : null,
          ),
          const SizedBox(height: 12),

          // Lichess account
          _AccountTile(
            platform: 'lichess',
            platformName: 'Lichess',
            username: lichessUsername,
            icon: '♞',
            iconBgColor: Colors.white,
            iconBorder: true,
            isDark: isDark,
            onEdit: () {
              Navigator.pop(context);
              showLinkAccountSheet(context, ref, platform: 'lichess');
            },
            onDelete: lichessUsername != null
                ? () => _confirmUnlink(
                      context,
                      ref,
                      'Lichess',
                      lichessUsername,
                      () => ref.read(authProvider.notifier).unlinkLichessAccount(),
                    )
                : null,
          ),

          const SizedBox(height: 24),

          // Add new account button (if neither is linked)
          if (chessComUsername == null || lichessUsername == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final platform = chessComUsername == null ? 'chesscom' : 'lichess';
                  showLinkAccountSheet(context, ref, platform: platform);
                },
                icon: const Icon(Icons.add),
                label: const Text('Link Another Account'),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmUnlink(
    BuildContext context,
    WidgetRef ref,
    String platformName,
    String username,
    Future<void> Function() onConfirm,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unlink $platformName?'),
        content: Text(
          'Are you sure you want to unlink "$username"?\n\n'
          'Your imported games will remain, but you won\'t be able to import new games from this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog first

              await onConfirm();

              // Invalidate games provider so it recreates with new usernames
              ref.invalidate(gamesProvider);

              // Refresh profile if needed
              final profile = ref.read(authProvider).profile;
              if (profile != null) {
                ref.read(profileProvider(profile.id).notifier).refresh();
              }

              // Close bottom sheet after a small delay to avoid navigator lock
              await Future.delayed(const Duration(milliseconds: 100));
              if (context.mounted) {
                Navigator.pop(context); // Close bottom sheet
              }

              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('$platformName account unlinked')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String platform;
  final String platformName;
  final String? username;
  final String icon;
  final Color iconBgColor;
  final bool iconBorder;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _AccountTile({
    required this.platform,
    required this.platformName,
    required this.username,
    required this.icon,
    required this.iconBgColor,
    this.iconBorder = false,
    required this.isDark,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLinked = username != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
              border: iconBorder ? Border.all(color: Colors.grey[300]!) : null,
            ),
            child: Center(
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: 22,
                  color: iconBorder ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Platform info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platformName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLinked ? username! : 'Not linked',
                  style: TextStyle(
                    fontSize: 13,
                    color: isLinked
                        ? (isDark ? Colors.grey[400] : Colors.grey[600])
                        : Colors.grey[500],
                    fontStyle: isLinked ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (isLinked) ...[
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: onDelete,
              tooltip: 'Unlink',
            ),
          ] else ...[
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Link'),
            ),
          ],
        ],
      ),
    );
  }
}
