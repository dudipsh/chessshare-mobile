import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/colors.dart';
import 'lemonsqueezy_service.dart';
import 'limits_tracker.dart';
import 'subscription_tier.dart';

/// Shows a modal when user hits their limit with upgrade options
class UpgradeModal extends StatefulWidget {
  final LimitCheckResult result;
  final String feature;
  final SubscriptionTier currentTier;

  const UpgradeModal({
    super.key,
    required this.result,
    required this.feature,
    required this.currentTier,
  });

  static Future<void> show(
    BuildContext context, {
    required LimitCheckResult result,
    required String feature,
    required SubscriptionTier currentTier,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpgradeModal(
        result: result,
        feature: feature,
        currentTier: currentTier,
      ),
    );
  }

  @override
  State<UpgradeModal> createState() => _UpgradeModalState();
}

class _UpgradeModalState extends State<UpgradeModal> {
  bool _isLoading = false;
  SubscriptionTier _selectedTier = SubscriptionTier.pro;

  Future<void> _openCheckout() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to upgrade')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await LemonSqueezyService.openCheckout(
      tier: _selectedTier,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 32,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Limit Reached',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                widget.result.message ??
                    'You\'ve reached your daily limit for ${widget.feature}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Plan selection
              _PlanSelector(
                currentTier: widget.currentTier,
                selectedTier: _selectedTier,
                onTierSelected: (tier) => setState(() => _selectedTier = tier),
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _openCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Upgrade to ${_selectedTier.displayName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Maybe later
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSelector extends StatelessWidget {
  final SubscriptionTier currentTier;
  final SubscriptionTier selectedTier;
  final ValueChanged<SubscriptionTier> onTierSelected;
  final bool isDark;

  const _PlanSelector({
    required this.currentTier,
    required this.selectedTier,
    required this.onTierSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (currentTier == SubscriptionTier.free) ...[
          Expanded(
            child: _PlanCard(
              tier: SubscriptionTier.basic,
              isSelected: selectedTier == SubscriptionTier.basic,
              onTap: () => onTierSelected(SubscriptionTier.basic),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _PlanCard(
            tier: SubscriptionTier.pro,
            isSelected: selectedTier == SubscriptionTier.pro,
            onTap: () => onTierSelected(SubscriptionTier.pro),
            isDark: isDark,
            isRecommended: true,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final bool isRecommended;

  const _PlanCard({
    required this.tier,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final limits = TierLimits.forTier(tier);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tier.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                if (isRecommended) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Best',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '\$${tier.monthlyPrice.toStringAsFixed(2)}/mo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 12),
            _FeatureRow(
              text:
                  '${limits.isUnlimited(limits.dailyGameReviews) ? "Unlimited" : limits.dailyGameReviews} reviews/day',
              isDark: isDark,
            ),
            _FeatureRow(
              text:
                  '${limits.isUnlimited(limits.dailyBoardViews) ? "Unlimited" : limits.dailyBoardViews} board views/day',
              isDark: isDark,
            ),
            _FeatureRow(
              text:
                  '${limits.isUnlimited(limits.maxBoards) ? "Unlimited" : limits.maxBoards} boards',
              isDark: isDark,
            ),
            if (limits.canCreateClub)
              _FeatureRow(text: 'Create clubs', isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final bool isDark;

  const _FeatureRow({
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 14,
            color: Colors.green[600],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple snackbar for limit warnings
void showLimitWarning(BuildContext context, LimitCheckResult result) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.displayMessage),
      backgroundColor: Colors.orange,
      action: SnackBarAction(
        label: 'Upgrade',
        textColor: Colors.white,
        onPressed: () {
          UpgradeModal.show(
            context,
            result: result,
            feature: 'this feature',
            currentTier: SubscriptionTier.free,
          );
        },
      ),
    ),
  );
}
