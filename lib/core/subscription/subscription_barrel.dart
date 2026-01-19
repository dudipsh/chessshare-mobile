// Subscription & Limits System with LemonSqueezy Integration
//
// Use this to manage user subscriptions and enforce daily limits.
// Integrates with LemonSqueezy for checkout and the web app's Supabase backend.
//
// Tiers (matching web app):
// - FREE: 1 game review/day, 3 board views/day, 5 max boards
// - BASIC ($4.99/mo): 3 game reviews/day, 50 board views/day, 20 max boards, can create clubs
// - PRO ($9.99/mo): Unlimited everything
//
// Example usage:
// ```dart
// class AnalysisScreen extends ConsumerWidget {
//   Future<void> startAnalysis(WidgetRef ref) async {
//     final notifier = ref.read(subscriptionProvider.notifier);
//     final result = await notifier.checkAndRecordGameReview();
//
//     if (!result.allowed) {
//       // Show upgrade modal
//       UpgradeModal.show(context, result: result, feature: 'Game Review', currentTier: tier);
//       return;
//     }
//
//     // Proceed with analysis...
//   }
// }
// ```
//
// Checkout flow:
// 1. User taps "Upgrade" in UpgradeModal
// 2. LemonSqueezyService opens checkout in browser
// 3. User completes purchase
// 4. LemonSqueezy webhook updates Supabase
// 5. Realtime notification triggers subscription refresh
// 6. App shows new subscription status

export 'subscription_tier.dart';
export 'limits_tracker.dart';
export 'subscription_service.dart';
export 'subscription_provider.dart';
export 'upgrade_modal.dart';
export 'lemonsqueezy_service.dart';
export 'deep_link_service.dart';
