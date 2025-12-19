import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/chess_game.dart';
import '../providers/games_provider.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/game_card.dart';
import '../widgets/games_empty_state.dart';
import '../widgets/games_stats_bar.dart';
import '../widgets/import_sheet.dart';

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
            onPressed: () => FilterSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => ImportSheet.show(context),
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
      return GamesEmptyState(
        onImportPressed: () => ImportSheet.show(context),
      );
    }

    // Show filtered empty state
    if (games.isEmpty) {
      return GamesNoResultsState(
        onClearFilters: () {
          ref.read(gamesFilterProvider.notifier).state = GamesFilter();
          _searchController.clear();
        },
      );
    }

    // Show games list with stats header
    return Column(
      children: [
        const GamesStatsBar(),
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
                      // Navigate to game review with auto-analysis
                      context.pushNamed('game-review', extra: game);
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
}
