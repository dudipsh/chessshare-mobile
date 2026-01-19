import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/subscription/lemonsqueezy_service.dart';
import '../../../../core/subscription/subscription_tier.dart';
import '../../../auth/providers/auth_provider.dart';

class PlanTab extends ConsumerStatefulWidget {
  final bool isDark;

  const PlanTab({super.key, required this.isDark});

  @override
  ConsumerState<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<PlanTab> {
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
    final profile = ref.watch(authProvider).profile;
    final currentTier = SubscriptionTier.fromString(profile?.subscriptionType);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Plan Card
              _CurrentPlanCard(
                currentTier: currentTier,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 24),

              // Available Plans
              Text(
                'Available Plans',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              _PlanCard(
                tier: SubscriptionTier.free,
                features: const [
                  '1 game review per day',
                  '3 board views per day',
                  '5 boards max',
                  '1 daily puzzle',
                ],
                isCurrentPlan: currentTier == SubscriptionTier.free,
                isDark: widget.isDark,
                onSelect: () {},
              ),
              const SizedBox(height: 12),

              _PlanCard(
                tier: SubscriptionTier.basic,
                features: const [
                  '3 game reviews per day',
                  '50 board views per day',
                  '20 boards max',
                  '3 daily puzzles',
                  'All variations access',
                  'Create clubs',
                  'Change cover images',
                ],
                isCurrentPlan: currentTier == SubscriptionTier.basic,
                isDark: widget.isDark,
                onSelect: () => _openCheckout(SubscriptionTier.basic),
              ),
              const SizedBox(height: 12),

              _PlanCard(
                tier: SubscriptionTier.pro,
                features: const [
                  'Unlimited game reviews',
                  'Unlimited board views',
                  'Unlimited boards',
                  'Unlimited daily puzzles',
                  'All variations access',
                  'Create clubs',
                  'Change cover images',
                  'Priority support',
                ],
                isCurrentPlan: currentTier == SubscriptionTier.pro,
                isRecommended: true,
                isDark: widget.isDark,
                onSelect: () => _openCheckout(SubscriptionTier.pro),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionTier currentTier;
  final bool isDark;

  const _CurrentPlanCard({
    required this.currentTier,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = currentTier != SubscriptionTier.free;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]
              : [
                  isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  isDark ? Colors.grey[850]! : Colors.grey[50]!,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isPremium
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPremium
                  ? Colors.white.withValues(alpha: 0.2)
                  : (isDark ? Colors.grey[700] : Colors.white),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getTierIcon(currentTier),
              size: 32,
              color: isPremium ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPremium
                        ? Colors.white.withValues(alpha: 0.8)
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTier.displayName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getTierIcon(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Icons.person;
      case SubscriptionTier.basic:
        return Icons.star;
      case SubscriptionTier.pro:
        return Icons.workspace_premium;
      case SubscriptionTier.admin:
        return Icons.admin_panel_settings;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isRecommended;
  final bool isDark;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.tier,
    required this.features,
    required this.isCurrentPlan,
    this.isRecommended = false,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final price = tier == SubscriptionTier.free
        ? 'Free'
        : '\$${tier.monthlyPrice.toStringAsFixed(2)}';
    final period = tier == SubscriptionTier.free ? '' : '/month';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended
              ? AppColors.primary
              : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
          width: isRecommended ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'RECOMMENDED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tier.displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            period,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan || tier == SubscriptionTier.free
                        ? null
                        : onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? (isDark ? Colors.grey[700] : Colors.grey[300])
                          : AppColors.primary,
                      foregroundColor: isCurrentPlan
                          ? (isDark ? Colors.grey[400] : Colors.grey[600])
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isCurrentPlan
                          ? 'Current Plan'
                          : tier == SubscriptionTier.free
                              ? 'Free'
                              : 'Upgrade to ${tier.displayName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
