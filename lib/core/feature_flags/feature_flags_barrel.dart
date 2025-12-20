/// Feature Flags System
///
/// Use this to conditionally enable/disable features based on:
/// - Global settings from Supabase
/// - User-specific overrides
/// - Subscription tier
///
/// Example usage:
/// ```dart
/// // In a widget
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     // Check single flag
///     if (ref.isFeatureEnabled(FeatureFlag.gamification)) {
///       return XpBadge();
///     }
///
///     // Or use FeatureGuard widget
///     return FeatureGuard(
///       flag: FeatureFlag.dailyPuzzles,
///       child: DailyPuzzleButton(),
///       fallback: ComingSoonBadge(),
///     );
///   }
/// }
/// ```

export 'feature_flags.dart';
export 'feature_flag_service.dart';
export 'feature_flag_provider.dart';
export 'feature_guard.dart';
