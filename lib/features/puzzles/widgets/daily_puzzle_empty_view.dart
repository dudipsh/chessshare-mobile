import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/daily_puzzle_provider.dart';
import 'date_navigation_header.dart';

class DailyPuzzleEmptyView extends StatelessWidget {
  final DailyPuzzleState state;
  final bool isDark;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onGoToToday;

  const DailyPuzzleEmptyView({
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
              const SizedBox(height: 32),
              Icon(
                Icons.extension_off,
                size: 80,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                'No Puzzle Available',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Import games to generate personalized puzzles',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!state.isToday) ...[
                ElevatedButton.icon(
                  onPressed: onGoToToday,
                  icon: const Icon(Icons.today),
                  label: const Text("Go to Today's Puzzle"),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => context.pushNamed('games'),
                child: const Text('Import Games'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
