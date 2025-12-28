import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../providers/daily_puzzle_provider.dart';
import 'date_navigation_header.dart';

class DailyPuzzleSolvedView extends StatelessWidget {
  final DailyPuzzleState state;
  final bool isDark;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onGoToToday;

  const DailyPuzzleSolvedView({
    super.key,
    required this.state,
    required this.isDark,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 4),
          DateNavigationHeader(
            selectedDate: state.selectedDate,
            isToday: state.isToday,
            isDark: isDark,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
          const SizedBox(height: 24),
          // Success card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  state.isToday ? "Today's Puzzle Complete!" : "Puzzle Solved!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (state.streak > 0 && state.isToday) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '${state.streak} day streak!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  state.isToday
                      ? 'Come back tomorrow for a new challenge'
                      : 'You solved this puzzle',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          if (!state.isToday)
            _buildActionButton(
              icon: Icons.today,
              label: "Go to Today's Puzzle",
              onPressed: onGoToToday,
              gradientColors: [Colors.green.shade400, Colors.teal.shade600],
              isDark: isDark,
            ),
          if (!state.isToday) const SizedBox(height: 8),
          _buildActionButton(
            icon: Icons.extension,
            label: 'Practice Game Puzzles',
            onPressed: () => context.pushNamed('puzzles'),
            gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
            isDark: isDark,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors.map((c) => c.withValues(alpha: 0.15)).toList(),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: gradientColors[1]),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? gradientColors[0] : gradientColors[1],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
