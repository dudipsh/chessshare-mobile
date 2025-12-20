import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gamification_provider.dart';
import 'streak_modal.dart';
import 'xp_popup.dart';

/// A widget that listens to gamification state changes and shows popups
class GamificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const GamificationListener({super.key, required this.child});

  @override
  ConsumerState<GamificationListener> createState() => _GamificationListenerState();
}

class _GamificationListenerState extends ConsumerState<GamificationListener> {
  bool _hasShownStreak = false;
  bool _hasShownXp = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<GamificationState>(gamificationProvider, (previous, next) {
      debugPrint('[GamificationListener] State changed: hasPendingXp=${next.hasPendingXp}, hasPendingStreak=${next.hasPendingStreak}, _hasShownXp=$_hasShownXp');

      // Show streak modal first (more important UX for daily login)
      if (next.hasPendingStreak && !_hasShownStreak) {
        debugPrint('[GamificationListener] Showing streak modal');
        _hasShownStreak = true;
        _showStreakModal(context, next);
      }
      // Then show XP popup if there's pending XP (and not from streak bonus)
      else if (next.hasPendingXp && !_hasShownXp && !next.hasPendingStreak) {
        debugPrint('[GamificationListener] Showing XP popup');
        _hasShownXp = true;
        _showXpPopup(context, next);
      }

      // Reset flags when pending data is cleared
      if (previous?.hasPendingStreak == true && !next.hasPendingStreak) {
        _hasShownStreak = false;
      }
      if (previous?.hasPendingXp == true && !next.hasPendingXp) {
        _hasShownXp = false;
      }
    });

    return widget.child;
  }

  void _showStreakModal(BuildContext context, GamificationState state) {
    final result = state.pendingStreakResult;
    if (result == null) return;

    StreakModal.show(
      context,
      result: result,
      totalStreak: state.currentStreak,
    ).then((_) {
      // Clear the pending streak after dismissing
      ref.read(gamificationProvider.notifier).clearPendingStreakResult();

      // Now show XP popup if there was an XP bonus
      if (state.hasPendingXp) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _showXpPopup(context, state);
          }
        });
      }
    });
  }

  void _showXpPopup(BuildContext context, GamificationState state) {
    final result = state.pendingXpAward;
    if (result == null || result.xpAwarded <= 0) return;

    XpPopup.show(
      context,
      result: result,
      onDismiss: () {
        ref.read(gamificationProvider.notifier).clearPendingXpAward();
      },
    );
  }
}
