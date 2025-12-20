import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../games/providers/games_provider.dart';
import '../../providers/profile_provider.dart';

void showLinkAccountSheet(BuildContext context, WidgetRef ref, {String platform = 'chesscom'}) {
  final controller = TextEditingController();
  final profile = ref.read(authProvider).profile;
  controller.text = platform == 'chesscom' ? (profile?.chessComUsername ?? '') : (profile?.lichessUsername ?? '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            platform == 'chesscom' ? 'Chess.com Username' : 'Lichess Username',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter username',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showLinkAccountSheet(context, ref, platform: platform == 'chesscom' ? 'lichess' : 'chesscom');
                  },
                  child: Text(platform == 'chesscom' ? 'Lichess instead' : 'Chess.com instead'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final username = controller.text.trim();
                    if (username.isNotEmpty) {
                      if (platform == 'chesscom') {
                        await ref.read(authProvider.notifier).updateChessComUsername(username);
                      } else {
                        await ref.read(authProvider.notifier).updateLichessUsername(username);
                      }
                      // Invalidate games provider to refresh with new account
                      ref.invalidate(gamesProvider);
                      // Also refresh profile provider if available
                      if (profile != null) {
                        ref.read(profileProvider(profile.id).notifier).refresh();
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
