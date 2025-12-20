import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../models/xp_models.dart';

/// Animated popup showing XP earned
class XpPopup extends StatefulWidget {
  final XpAwardResult result;
  final VoidCallback? onDismiss;

  const XpPopup({
    super.key,
    required this.result,
    this.onDismiss,
  });

  /// Show XP popup as a dialog
  static void show(
    BuildContext context, {
    required XpAwardResult result,
    VoidCallback? onDismiss,
  }) {
    // Use rootNavigatorKey's state directly to push the dialog
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) {
      debugPrint('[XpPopup] No navigator state available');
      return;
    }

    debugPrint('[XpPopup] Showing XP popup with ${result.xpAwarded} XP');

    // Push a custom route directly using the navigator state
    navigatorState.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                child: Material(
                  color: Colors.transparent,
                  child: XpPopup(
                    result: result,
                    onDismiss: () {
                      navigatorState.pop();
                      onDismiss?.call();
                    },
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          );
        },
      ),
    );

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (navigatorState.canPop()) {
        navigatorState.pop();
        onDismiss?.call();
      }
    });
  }

  @override
  State<XpPopup> createState() => _XpPopupState();
}

class _XpPopupState extends State<XpPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // XP earned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AnimatedXpIcon(),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.result.xpAwarded} XP',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Level progress
                  _LevelProgress(result: widget.result, isDark: isDark),

                  // Level up message
                  if (widget.result.leveledUp) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Level Up! ${widget.result.newTitle ?? ""}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedXpIcon extends StatefulWidget {
  @override
  State<_AnimatedXpIcon> createState() => _AnimatedXpIconState();
}

class _AnimatedXpIconState extends State<_AnimatedXpIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.2),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

class _LevelProgress extends StatelessWidget {
  final XpAwardResult result;
  final bool isDark;

  const _LevelProgress({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final levelInfo = LevelInfo.fromXp(result.newTotalXp);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Level ${levelInfo.level}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              '${levelInfo.currentXp - levelInfo.xpForCurrentLevel}/${LevelInfo.xpPerLevel} XP',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: levelInfo.progressToNextLevel,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
