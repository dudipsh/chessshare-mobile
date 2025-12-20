import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/colors.dart';
import 'limits_tracker.dart';
import 'subscription_tier.dart';

/// Shows a modal when user hits their limit
class UpgradeModal extends StatelessWidget {
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

  void _openUpgradeUrl() async {
    // TODO: Replace with actual upgrade URL
    const url = 'https://chessy.app/pricing';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                result.message ?? 'You\'ve reached your daily limit for $feature.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Current vs upgraded comparison
              _ComparisonCard(
                feature: feature,
                currentTier: currentTier,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openUpgradeUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Upgrade Now',
                    style: TextStyle(
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

class _ComparisonCard extends StatelessWidget {
  final String feature;
  final SubscriptionTier currentTier;
  final bool isDark;

  const _ComparisonCard({
    required this.feature,
    required this.currentTier,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currentLimits = TierLimits.forTier(currentTier);
    final proLimits = TierLimits.forTier(SubscriptionTier.pro);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TierColumn(
                  tierName: currentTier.displayName,
                  limits: currentLimits,
                  isCurrent: true,
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              Expanded(
                child: _TierColumn(
                  tierName: 'Pro',
                  limits: proLimits,
                  isCurrent: false,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierColumn extends StatelessWidget {
  final String tierName;
  final TierLimits limits;
  final bool isCurrent;
  final bool isDark;

  const _TierColumn({
    required this.tierName,
    required this.limits,
    required this.isCurrent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          tierName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrent
                ? (isDark ? Colors.grey[400] : Colors.grey[600])
                : AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        _LimitRow(
          label: 'Analyses',
          value: limits.isUnlimited(limits.dailyAnalyses)
              ? '∞'
              : '${limits.dailyAnalyses}/day',
          isDark: isDark,
        ),
        _LimitRow(
          label: 'Boards',
          value: limits.isUnlimited(limits.dailyBoardViews)
              ? '∞'
              : '${limits.dailyBoardViews}/day',
          isDark: isDark,
        ),
        _LimitRow(
          label: 'Variations',
          value: limits.allVariations ? 'All' : 'First only',
          isDark: isDark,
        ),
      ],
    );
  }
}

class _LimitRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _LimitRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
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
          // TODO: Navigate to upgrade
        },
      ),
    ),
  );
}
