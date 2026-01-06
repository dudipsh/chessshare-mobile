import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../auth/providers/auth_provider.dart';

class PlanTab extends ConsumerWidget {
  final bool isDark;

  const PlanTab({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final currentPlan = (profile?.subscriptionType ?? 'FREE').toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Plan Card
          _CurrentPlanCard(
            currentPlan: currentPlan,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Available Plans
          Text(
            'Available Plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          _PlanCard(
            name: 'Free',
            price: 'Free',
            period: '',
            features: const [
              '3 boards per day',
              '5 boards total',
              'Basic analysis',
              'Community support',
            ],
            isCurrentPlan: currentPlan == 'free',
            isDark: isDark,
            onSelect: () {},
          ),
          const SizedBox(height: 12),

          _PlanCard(
            name: 'Basic',
            price: '\$4.99',
            period: '/month',
            features: const [
              '10 boards per day',
              '20 boards total',
              'Change cover image',
              'Basic analysis',
            ],
            isCurrentPlan: currentPlan == 'basic',
            isDark: isDark,
            onSelect: () => _showUpgradeDialog(context, 'basic'),
          ),
          const SizedBox(height: 12),

          _PlanCard(
            name: 'Pro',
            price: '\$9.99',
            period: '/month',
            features: const [
              'Unlimited viewing',
              'Unlimited creation',
              'Create clubs',
              'Advanced analysis',
              'Priority support',
            ],
            isCurrentPlan: currentPlan == 'pro',
            isRecommended: true,
            isDark: isDark,
            onSelect: () => _showUpgradeDialog(context, 'pro'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, String plan) {
    final planName = plan[0].toUpperCase() + plan.substring(1);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to $planName'),
        content: const Text('Subscription management will be available soon. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final String currentPlan;
  final bool isDark;

  const _CurrentPlanCard({
    required this.currentPlan,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final planName = currentPlan[0].toUpperCase() + currentPlan.substring(1);
    final isPremium = currentPlan != 'free';

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
              isPremium ? Icons.workspace_premium : Icons.person,
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
                  planName,
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
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isRecommended;
  final bool isDark;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.isCurrentPlan,
    this.isRecommended = false,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                      name,
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
                          style: TextStyle(
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
                          Icon(
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
                    onPressed: isCurrentPlan ? null : onSelect,
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
                      isCurrentPlan ? 'Current Plan' : 'Select Plan',
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
