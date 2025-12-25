import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../providers/exploration_mode_provider.dart';

class ExplorationBar extends ConsumerWidget {
  final ExplorationState explorationState;
  final bool isDark;

  const ExplorationBar({
    super.key,
    required this.explorationState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'Exploring',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          if (explorationState.explorationMoves.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '(${explorationState.explorationMoves.length} moves)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              ref.read(explorationModeProvider.notifier).returnToGame();
            },
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Back to game'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
