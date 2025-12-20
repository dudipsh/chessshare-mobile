/// Gamification System
///
/// XP, Levels, and Daily Login Streaks
///
/// Level Formula: Level = floor(XP / 200) + 1
/// - Level 1: 0-199 XP
/// - Level 2: 200-399 XP
/// - etc.
///
/// XP Awards:
/// - Complete Study Line: 50 XP
/// - Daily Puzzle Solve: 25 XP
/// - Game Analysis: 30 XP
/// - Practice Mistake Correct: 15 XP
///
/// Daily Streak Bonuses:
/// - 2 days: +25 XP
/// - 3 days: +35 XP
/// - 5 days: +50 XP
/// - 7 days: +75 XP
/// - 14 days: +150 XP
/// - 30 days: +300 XP
///
/// Example usage:
/// ```dart
/// // Award XP after completing a study line
/// final result = await ref.read(gamificationProvider.notifier).awardXp(
///   XpEventType.studyLineComplete,
///   relatedId: boardId,
/// );
///
/// // Show XP popup if earned
/// if (result != null && result.xpAwarded > 0) {
///   XpPopup.show(context, result: result);
/// }
///
/// // Show level/streak badges in UI
/// Row(
///   children: [
///     LevelBadge(compact: true),
///     SizedBox(width: 8),
///     StreakBadge(),
///   ],
/// )
/// ```

export 'models/xp_models.dart';
export 'models/streak_models.dart';
export 'services/gamification_service.dart';
export 'providers/gamification_provider.dart';
export 'widgets/xp_popup.dart';
export 'widgets/streak_modal.dart';
export 'widgets/level_badge.dart';
