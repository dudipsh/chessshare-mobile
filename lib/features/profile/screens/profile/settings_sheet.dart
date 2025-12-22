import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/subscription/subscription_provider.dart';
import '../../../../core/subscription/subscription_tier.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../widgets/subscription_sheet.dart';

void showProfileSettingsSheet(BuildContext context, WidgetRef ref) {
  final themeState = ref.watch(themeProvider);
  final isDark = themeState.mode == AppThemeMode.dark ||
      (themeState.mode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => _SettingsSheetContent(
        scrollController: scrollController,
        isDark: isDark,
      ),
    ),
  );
}

class _SettingsSheetContent extends ConsumerWidget {
  final ScrollController scrollController;
  final bool isDark;

  const _SettingsSheetContent({
    required this.scrollController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final currentTier = subscriptionState.tier;

    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildHandle(),
          _buildHeader(),
          const SizedBox(height: 8),
          _buildSectionHeader('Subscription'),
          SubscriptionTile(
            currentTier: currentTier,
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              _showSubscriptionInfo(context, currentTier);
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Appearance'),
          _buildDarkModeToggle(context, ref, themeState),
          const SizedBox(height: 16),
          _buildSectionHeader('Legal & Support'),
          _buildLegalLinks(context),
          const SizedBox(height: 16),
          _buildSectionHeader('Account'),
          _buildAccountActions(context, ref),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHandle() {
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle(BuildContext context, WidgetRef ref, ThemeState themeState) {
    return ListTile(
      leading: Icon(
        isDark ? Icons.dark_mode : Icons.light_mode,
        color: isDark ? Colors.amber : Colors.orange,
      ),
      title: const Text('Dark Mode'),
      trailing: Switch(
        value: themeState.mode == AppThemeMode.dark ||
            (themeState.mode == AppThemeMode.system &&
             MediaQuery.platformBrightnessOf(context) == Brightness.dark),
        onChanged: (v) => ref.read(themeProvider.notifier).setDarkMode(v),
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openUrl('https://www.chessshare.com/privacy-policy'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openUrl('https://www.chessshare.com/terms-of-service'),
        ),
        ListTile(
          leading: const Icon(Icons.support_agent_outlined),
          title: const Text('Help & Support'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openUrl('https://www.chessshare.com/legal-support'),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () {
            Navigator.pop(context);
            _showAboutDialog(context);
          },
        ),
      ],
    );
  }

  Widget _buildAccountActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
          title: Text('Delete Account', style: TextStyle(color: Colors.red.shade400)),
          onTap: () {
            Navigator.pop(context);
            _showDeleteAccountDialog(context, ref);
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            ref.read(authProvider.notifier).signOut();
          },
        ),
      ],
    );
  }

  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showSubscriptionInfo(BuildContext context, SubscriptionTier tier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SubscriptionInfoSheet(currentTier: tier),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ChessShare',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 50,
          height: 50,
          errorBuilder: (_, __, ___) => Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_esports, size: 30, color: AppColors.primary),
          ),
        ),
      ),
      children: const [
        Text('Learn, Share & Master Chess'),
        SizedBox(height: 8),
        Text('© 2025 ChessShare'),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. '
          'All your data, games, and progress will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please contact support@chessshare.com to delete your account'),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
