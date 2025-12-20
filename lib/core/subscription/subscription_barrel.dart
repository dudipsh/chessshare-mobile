/// Subscription & Limits System
///
/// Use this to manage user subscriptions and enforce daily limits.
///
/// Tiers:
/// - FREE: 2 analyses/day, 10 boards/day, first variation only
/// - BASIC: 10 analyses/day, 50 boards/day, all variations, 5 boards
/// - PRO: Unlimited everything
///
/// Example usage:
/// ```dart
/// class AnalysisScreen extends ConsumerWidget {
///   Future<void> startAnalysis(WidgetRef ref) async {
///     final notifier = ref.read(subscriptionProvider.notifier);
///     final result = await notifier.checkAndRecordAnalysis();
///
///     if (!result.allowed) {
///       // Show upgrade modal
///       UpgradeModal.show(context, result: result, feature: 'Game Analysis', currentTier: tier);
///       return;
///     }
///
///     // Proceed with analysis...
///   }
/// }
/// ```

export 'subscription_tier.dart';
export 'limits_tracker.dart';
export 'subscription_service.dart';
export 'subscription_provider.dart';
export 'upgrade_modal.dart';
