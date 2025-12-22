import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../../../core/subscription/subscription_tier.dart';

class SubscriptionInfoSheet extends StatelessWidget {
  final SubscriptionTier currentTier;

  const SubscriptionInfoSheet({super.key, required this.currentTier});

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
            _buildPlanCard('Free', 'Free', [
              '2 game analyses per day',
              '10 board views per day',
              '1 daily puzzle',
            ], currentTier == SubscriptionTier.free, Colors.grey, isDark),
            const SizedBox(height: 12),
            _buildPlanCard('Basic', '\$4.99/mo', [
              '10 game analyses per day',
              '50 board views per day',
              '3 daily puzzles',
              'All variations access',
              'Create up to 5 boards',
            ], currentTier == SubscriptionTier.basic, Colors.blue, isDark),
            const SizedBox(height: 12),
            _buildPlanCard('Pro', '\$9.99/mo', [
              'Unlimited analyses',
              'Unlimited board views',
              '5 daily puzzles',
              'All variations access',
              'Unlimited boards',
              'Priority support',
            ], currentTier == SubscriptionTier.pro, Colors.purple, isDark),
            const SizedBox(height: 24),
            _buildComingSoonMessage(isDark),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    String name,
    String price,
    List<String> features,
    bool isCurrentPlan,
    Color color,
    bool isDark,
  ) {
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
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
                Text(f, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildComingSoonMessage(bool isDark) {
    return Container(
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
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionTile extends StatelessWidget {
  final SubscriptionTier currentTier;
  final bool isDark;
  final VoidCallback onTap;

  const SubscriptionTile({
    super.key,
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
        child: Icon(_getTierIcon(currentTier), color: _getTierColor(currentTier)),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getTierColor(currentTier)),
            ),
          ),
          if (currentTier == SubscriptionTier.free) ...[
            const SizedBox(width: 8),
            Text(
              'Upgrade for more features',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
      case SubscriptionTier.free: return Colors.grey;
      case SubscriptionTier.basic: return Colors.blue;
      case SubscriptionTier.pro: return Colors.purple;
      case SubscriptionTier.admin: return Colors.amber;
    }
  }

  IconData _getTierIcon(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free: return Icons.person_outline;
      case SubscriptionTier.basic: return Icons.star_outline;
      case SubscriptionTier.pro: return Icons.workspace_premium;
      case SubscriptionTier.admin: return Icons.admin_panel_settings;
    }
  }
}
