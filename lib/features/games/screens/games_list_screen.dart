import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../models/chess_game.dart';
import '../providers/games_provider.dart';
import '../widgets/game_card.dart';

class GamesListScreen extends ConsumerStatefulWidget {
  const GamesListScreen({super.key});

  @override
  ConsumerState<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends ConsumerState<GamesListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gamesState = ref.watch(gamesProvider);
    final filteredGames = ref.watch(filteredGamesProvider);
    final filter = ref.watch(gamesFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search games...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(gamesFilterProvider.notifier).state =
                      filter.copyWith(search: value);
                },
              )
            : const Text('My Games'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(gamesFilterProvider.notifier).state =
                      filter.copyWith(search: '');
                }
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: filter.hasFilters,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(context, ref, filter),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showImportDialog(context),
          ),
        ],
      ),
      body: _buildBody(context, gamesState, filteredGames),
    );
  }

  Widget _buildBody(
    BuildContext context,
    GamesState gamesState,
    List<ChessGame> games,
  ) {
    // Show loading state
    if (gamesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty state if no games
    if (!gamesState.hasGames) {
      return _buildEmptyState(context);
    }

    // Show filtered empty state
    if (games.isEmpty) {
      return _buildNoResultsState(context);
    }

    // Show games list with stats header
    return Column(
      children: [
        // Stats bar
        _buildStatsBar(context),

        // Games list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Could refresh from API if we had stored usernames
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GameCard(
                    game: game,
                    onTap: () {
                      context.pushNamed('analysis', extra: game);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    final stats = ref.watch(gamesStatsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            '${stats['total']}',
            'Games',
            Colors.white70,
          ),
          _buildStatItem(
            context,
            '${stats['wins']}',
            'Wins',
            AppColors.win,
          ),
          _buildStatItem(
            context,
            '${stats['losses']}',
            'Losses',
            AppColors.loss,
          ),
          _buildStatItem(
            context,
            '${stats['draws']}',
            'Draws',
            AppColors.draw,
          ),
          _buildStatItem(
            context,
            '${(stats['winRate'] as double).toStringAsFixed(0)}%',
            'Win Rate',
            AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_esports_outlined,
                size: 50,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No games yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import your games from Chess.com or Lichess to start analyzing',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showImportDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Import Games'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No games match your filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(gamesFilterProvider.notifier).state = GamesFilter();
                _searchController.clear();
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Games',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _ImportOption(
              icon: Icons.public,
              title: 'Chess.com',
              subtitle: 'Import from your Chess.com account',
              onTap: () {
                Navigator.pop(context);
                context.push('/import/chesscom');
              },
            ),
            const SizedBox(height: 12),
            _ImportOption(
              icon: Icons.public,
              title: 'Lichess',
              subtitle: 'Import from your Lichess account',
              onTap: () {
                Navigator.pop(context);
                context.push('/import/lichess');
              },
            ),
            const SizedBox(height: 12),
            _ImportOption(
              icon: Icons.file_upload,
              title: 'PGN File',
              subtitle: 'Import from a PGN file',
              onTap: () {
                Navigator.pop(context);
                // TODO: Open file picker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PGN import coming soon')),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    GamesFilter filter,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                        ref.read(gamesFilterProvider.notifier).state =
                            GamesFilter();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Result filter
              Text(
                'Result',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
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
                      setModalState(() {});
                    },
                    selectedColor: AppColors.accent.withOpacity(0.3),
                    checkmarkColor: AppColors.accent,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Speed filter
              Text(
                'Time Control',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
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
                      setModalState(() {});
                    },
                    selectedColor: AppColors.accent.withOpacity(0.3),
                    checkmarkColor: AppColors.accent,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Platform filter
              Text(
                'Platform',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
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
                      setModalState(() {});
                    },
                    selectedColor: AppColors.accent.withOpacity(0.3),
                    checkmarkColor: AppColors.accent,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
