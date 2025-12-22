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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DateNavigationHeader(
                selectedDate: state.selectedDate,
                isToday: state.isToday,
                isDark: isDark,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                state.isToday ? "Today's Puzzle Complete!" : "Puzzle Solved!",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (state.streak > 0 && state.isToday) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '${state.streak} day streak!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                state.isToday
                    ? 'Come back tomorrow for a new challenge'
                    : 'You solved this puzzle',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!state.isToday)
                ElevatedButton.icon(
                  onPressed: onGoToToday,
                  icon: const Icon(Icons.today),
                  label: const Text("Go to Today's Puzzle"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
              if (!state.isToday) const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('puzzles'),
                icon: const Icon(Icons.extension),
                label: const Text('Practice Game Puzzles'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
