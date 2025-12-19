import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';

void showProfileSettingsSheet(BuildContext context, WidgetRef ref) {
  final themeState = ref.watch(themeProvider);
  final isDark = themeState.mode == AppThemeMode.dark ||
      (themeState.mode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: isDark,
              onChanged: (v) => ref.read(themeProvider.notifier).setDarkMode(v),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(ctx);
              showAboutDialog(context: context, applicationName: 'ChessShare', applicationVersion: '1.0.0');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
