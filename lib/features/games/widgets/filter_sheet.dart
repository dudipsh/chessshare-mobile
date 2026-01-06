import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../models/chess_game.dart';
import '../providers/games_provider.dart';

/// Bottom sheet for filtering games
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => const FilterSheet(),
      ),
    );
  }

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(gamesFilterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Games',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (filter.hasFilters)
                TextButton(
                  onPressed: () {
                    ref.read(gamesFilterProvider.notifier).state = GamesFilter();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Result filter
          _FilterSection(
            title: 'Result',
            child: Wrap(
              spacing: 8,
              children: GameResult.values.map((result) {
                final isSelected = filter.result == result;
                return FilterChip(
                  label: Text(result.name[0].toUpperCase() + result.name.substring(1)),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(gamesFilterProvider.notifier).state = filter.copyWith(
                      result: selected ? result : null,
                      clearResult: !selected,
                    );
                    setState(() {});
                  },
                  selectedColor: AppColors.accent.withOpacity(0.3),
                  checkmarkColor: AppColors.accent,
                );
              }).toList(),
            ),
          ),

          // Speed filter
          _FilterSection(
            title: 'Time Control',
            child: Wrap(
              spacing: 8,
              children: GameSpeed.values.map((speed) {
                final isSelected = filter.speed == speed;
                return FilterChip(
                  label: Text(speed.name[0].toUpperCase() + speed.name.substring(1)),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(gamesFilterProvider.notifier).state = filter.copyWith(
                      speed: selected ? speed : null,
                      clearSpeed: !selected,
                    );
                    setState(() {});
                  },
                  selectedColor: AppColors.accent.withOpacity(0.3),
                  checkmarkColor: AppColors.accent,
                );
              }).toList(),
            ),
          ),

          // Platform filter
          _FilterSection(
            title: 'Platform',
            child: Wrap(
              spacing: 8,
              children: GamePlatform.values.map((platform) {
                final isSelected = filter.platform == platform;
                final label = platform == GamePlatform.chesscom ? 'Chess.com' : 'Lichess';
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(gamesFilterProvider.notifier).state = filter.copyWith(
                      platform: selected ? platform : null,
                      clearPlatform: !selected,
                    );
                    setState(() {});
                  },
                  selectedColor: AppColors.accent.withOpacity(0.3),
                  checkmarkColor: AppColors.accent,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Extra padding at bottom to account for tab bar
          SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
