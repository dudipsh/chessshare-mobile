import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flag_provider.dart';
import 'feature_flags.dart';

/// Widget that conditionally shows content based on feature flag
class FeatureGuard extends ConsumerWidget {
  /// The feature flag to check
  final FeatureFlag flag;

  /// Widget to show when feature is enabled
  final Widget child;

  /// Optional widget to show when feature is disabled
  final Widget? fallback;

  /// If true, shows loading indicator while flags are loading
  final bool showLoading;

  /// Multiple flags that must ALL be enabled
  final List<FeatureFlag>? allFlags;

  /// Multiple flags where ANY must be enabled
  final List<FeatureFlag>? anyFlags;

  const FeatureGuard({
    super.key,
    required this.flag,
    required this.child,
    this.fallback,
    this.showLoading = false,
    this.allFlags,
    this.anyFlags,
  });

  /// Guard requiring ALL flags to be enabled
  const FeatureGuard.all({
    super.key,
    required List<FeatureFlag> flags,
    required this.child,
    this.fallback,
    this.showLoading = false,
  })  : flag = FeatureFlag.freeUserLimits, // Ignored when allFlags is set
        allFlags = flags,
        anyFlags = null;

  /// Guard requiring ANY flag to be enabled
  const FeatureGuard.any({
    super.key,
    required List<FeatureFlag> flags,
    required this.child,
    this.fallback,
    this.showLoading = false,
  })  : flag = FeatureFlag.freeUserLimits, // Ignored when anyFlags is set
        allFlags = null,
        anyFlags = flags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureFlagProvider);

    // Show loading if requested
    if (state.isLoading && showLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Determine if feature is enabled
    bool isEnabled;

    if (allFlags != null && allFlags!.isNotEmpty) {
      // All flags must be enabled
      isEnabled = allFlags!.every((f) => state.isEnabled(f));
    } else if (anyFlags != null && anyFlags!.isNotEmpty) {
      // Any flag must be enabled
      isEnabled = anyFlags!.any((f) => state.isEnabled(f));
    } else {
      // Single flag check
      isEnabled = state.isEnabled(flag);
    }

    if (isEnabled) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget that shows a "Coming Soon" badge when feature is disabled
class FeatureComingSoon extends ConsumerWidget {
  final FeatureFlag flag;
  final Widget child;
  final String? message;

  const FeatureComingSoon({
    super.key,
    required this.flag,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(isFeatureEnabledProvider(flag));

    if (isEnabled) {
      return child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Opacity(
          opacity: 0.5,
          child: IgnorePointer(child: child),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message ?? 'Coming Soon',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Extension for easy feature flag checking in widgets
extension FeatureFlagContextExtension on WidgetRef {
  /// Check if a feature is enabled
  bool isFeatureEnabled(FeatureFlag flag) {
    return watch(isFeatureEnabledProvider(flag));
  }

  /// Check if all features are enabled
  bool areAllFeaturesEnabled(List<FeatureFlag> flags) {
    final state = watch(featureFlagProvider);
    return flags.every((f) => state.isEnabled(f));
  }

  /// Check if any feature is enabled
  bool isAnyFeatureEnabled(List<FeatureFlag> flags) {
    final state = watch(featureFlagProvider);
    return flags.any((f) => state.isEnabled(f));
  }
}
