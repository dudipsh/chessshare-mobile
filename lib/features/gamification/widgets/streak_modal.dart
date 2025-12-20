import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/streak_models.dart';

/// Modal showing daily streak information
class StreakModal extends StatelessWidget {
  final StreakCheckResult result;
  final int totalStreak;
  final VoidCallback? onDismiss;

  const StreakModal({
    super.key,
    required this.result,
    required this.totalStreak,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required StreakCheckResult result,
    required int totalStreak,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreakModal(
        result: result,
        totalStreak: totalStreak,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
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

              // Fire icon with animation
              _AnimatedFireIcon(streakDays: result.newStreak),
              const SizedBox(height: 16),

              // Streak count
              Text(
                '${result.newStreak} Day Streak!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              if (result.milestoneMessage != null)
                Text(
                  result.milestoneMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                  ),
                )
              else if (result.streakBroken)
                Text(
                  'Your previous streak was broken, but you\'re back! Keep going!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                )
              else
                Text(
                  'Keep coming back every day to build your streak!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),

              // XP bonus
              if (result.xpBonus > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: AppColors.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '+${result.xpBonus} XP Bonus',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Streak calendar preview
              _StreakCalendar(currentStreak: result.newStreak, isDark: isDark),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Keep Going!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

class _AnimatedFireIcon extends StatefulWidget {
  final int streakDays;

  const _AnimatedFireIcon({required this.streakDays});

  @override
  State<_AnimatedFireIcon> createState() => _AnimatedFireIconState();
}

class _AnimatedFireIconState extends State<_AnimatedFireIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getFireColor() {
    if (widget.streakDays >= 30) return Colors.purple;
    if (widget.streakDays >= 14) return Colors.blue;
    if (widget.streakDays >= 7) return Colors.orange;
    return Colors.deepOrange;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getFireColor();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.1),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department,
              size: 48,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _StreakCalendar extends StatelessWidget {
  final int currentStreak;
  final bool isDark;

  const _StreakCalendar({required this.currentStreak, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (index) {
        final day = index + 1;
        final isCompleted = day <= currentStreak;
        final isToday = day == currentStreak;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.deepOrange
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '$day',
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getDayName(index),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _getDayName(int index) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[index];
  }
}
