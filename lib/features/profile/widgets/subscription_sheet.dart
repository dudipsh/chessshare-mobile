import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/colors.dart';
import '../../../core/subscription/lemonsqueezy_service.dart';
import '../../../core/subscription/subscription_tier.dart';

class SubscriptionInfoSheet extends StatefulWidget {
  final SubscriptionTier currentTier;

  const SubscriptionInfoSheet({super.key, required this.currentTier});

  @override
  State<SubscriptionInfoSheet> createState() => _SubscriptionInfoSheetState();
}

class _SubscriptionInfoSheetState extends State<SubscriptionInfoSheet> {
  bool _isLoading = false;

  Future<void> _openCheckout(SubscriptionTier tier) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to upgrade')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await LemonSqueezyService.openCheckout(
      tier: tier,
      userId: user.id,
      email: user.email ?? '',
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete your purchase in the browser'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open checkout')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Stack(
          children: [
            ListView(
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
                _buildPlanCard(
                  tier: SubscriptionTier.free,
                  features: [
                    '1 game review per day',
                    '3 board views per day',
                    '5 boards max',
                    '1 daily puzzle',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  tier: SubscriptionTier.basic,
                  features: [
                    '3 game reviews per day',
                    '50 board views per day',
                    '20 boards max',
                    '3 daily puzzles',
                    'All variations access',
                    'Create clubs',
                    'Change cover images',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  tier: SubscriptionTier.pro,
                  features: [
                    'Unlimited game reviews',
                    'Unlimited board views',
                    'Unlimited boards',
                    'Unlimited daily puzzles',
                    'All variations access',
                    'Create clubs',
                    'Change cover images',
                    'Priority support',
                  ],
                  isDark: isDark,
                  isRecommended: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionTier tier,
    required List<String> features,
    required bool isDark,
    bool isRecommended = false,
  }) {
    final isCurrentPlan = widget.currentTier == tier;
    final canUpgrade = tier != SubscriptionTier.free &&
                       widget.currentTier.index < tier.index;
    final color = _getTierColor(tier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? color.withOpacity(0.1)
            : (isDark ? Colors.grey[850] : Colors.grey[100]),
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
                    tier.displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCurrentPlan
                          ? color
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (isCurrentPlan) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                  if (isRecommended && !isCurrentPlan) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'BEST VALUE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                tier == SubscriptionTier.free
                    ? 'Free'
                    : '\$${tier.monthlyPrice.toStringAsFixed(2)}/mo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.white70 : Colors.black54)),
                    ),
                  ],
                ),
              )),
          if (canUpgrade) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _openCheckout(tier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Upgrade to ${tier.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
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
        child:
            Icon(_getTierIcon(currentTier), color: _getTierColor(currentTier)),
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
                  color: _getTierColor(currentTier)),
            ),
          ),
          if (currentTier == SubscriptionTier.free) ...[
            const SizedBox(width: 8),
            Text(
              'Upgrade for more features',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
