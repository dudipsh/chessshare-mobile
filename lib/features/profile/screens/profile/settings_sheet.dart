import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/subscription/subscription_provider.dart';
import '../../../../core/subscription/subscription_tier.dart';
import '../../../auth/providers/auth_provider.dart';

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
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ============ Subscription Section ============
          _SectionHeader(title: 'Subscription', isDark: isDark),

          _SubscriptionTile(
            currentTier: currentTier,
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              _showSubscriptionInfo(context, currentTier);
            },
          ),

          const SizedBox(height: 16),

          // ============ Appearance Section ============
          _SectionHeader(title: 'Appearance', isDark: isDark),

          ListTile(
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
          ),

          const SizedBox(height: 16),

          // ============ Legal & Support Section ============
          _SectionHeader(title: 'Legal & Support', isDark: isDark),

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
                children: [
                  const Text('Learn, Share & Master Chess'),
                  const SizedBox(height: 8),
                  const Text('© 2025 ChessShare'),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // ============ Account Section ============
          _SectionHeader(title: 'Account', isDark: isDark),

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

          const SizedBox(height: 24),
        ],
      ),
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
      builder: (ctx) => _SubscriptionInfoSheet(currentTier: tier),
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
              // TODO: Implement account deletion
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
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
}

class _SubscriptionTile extends StatelessWidget {
  final SubscriptionTier currentTier;
  final bool isDark;
  final VoidCallback onTap;

  const _SubscriptionTile({
    required this.currentTier,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getTierColor(currentTier).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getTierIcon(currentTier),
          color: _getTierColor(currentTier),
        ),
      ),
      title: const Text('Current Plan'),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getTierColor(currentTier).withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              currentTier.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getTierColor(currentTier),
              ),
            ),
          ),
          if (currentTier == SubscriptionTier.free) ...[
            const SizedBox(width: 8),
            Text(
              'Upgrade for more features',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Color _getTierColor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Colors.grey;
      case SubscriptionTier.basic:
        return Colors.blue;
      case SubscriptionTier.pro:
        return Colors.purple;
      case SubscriptionTier.admin:
        return Colors.amber;
    }
  }

  IconData _getTierIcon(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Icons.person_outline;
      case SubscriptionTier.basic:
        return Icons.star_outline;
      case SubscriptionTier.pro:
        return Icons.workspace_premium;
      case SubscriptionTier.admin:
        return Icons.admin_panel_settings;
    }
  }
}

class _SubscriptionInfoSheet extends StatelessWidget {
  final SubscriptionTier currentTier;

  const _SubscriptionInfoSheet({required this.currentTier});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Subscription Plans',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Plans comparison
            _PlanCard(
              name: 'Free',
              price: 'Free',
              features: [
                '2 game analyses per day',
                '10 board views per day',
                '1 daily puzzle',
              ],
              isCurrentPlan: currentTier == SubscriptionTier.free,
              color: Colors.grey,
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _PlanCard(
              name: 'Basic',
              price: '\$4.99/mo',
              features: [
                '10 game analyses per day',
                '50 board views per day',
                '3 daily puzzles',
                'All variations access',
                'Create up to 5 boards',
              ],
              isCurrentPlan: currentTier == SubscriptionTier.basic,
              color: Colors.blue,
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            _PlanCard(
              name: 'Pro',
              price: '\$9.99/mo',
              features: [
                'Unlimited analyses',
                'Unlimited board views',
                '5 daily puzzles',
                'All variations access',
                'Unlimited boards',
                'Priority support',
              ],
              isCurrentPlan: currentTier == SubscriptionTier.pro,
              color: Colors.purple,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Coming soon message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'In-app purchases coming soon! Stay tuned for subscription options.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final List<String> features;
  final bool isCurrentPlan;
  final Color color;
  final bool isDark;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.features,
    required this.isCurrentPlan,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan ? color.withOpacity(0.1) : (isDark ? Colors.grey[850] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentPlan ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCurrentPlan ? color : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (isCurrentPlan) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.check, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  f,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
