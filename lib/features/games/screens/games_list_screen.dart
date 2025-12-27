import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/global_stockfish_manager.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../providers/games_provider.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/game_card.dart';
import '../widgets/games_empty_state.dart';
import '../widgets/games_stats_bar.dart';
import '../widgets/import_sheet.dart';
import 'games_list/games_loading_view.dart';
import 'games_list/login_required_view.dart';
import 'games_list/no_games_view.dart';
import 'games_list/platform_switcher.dart';
import 'games_list/quick_access_buttons.dart';

class GamesListScreen extends ConsumerStatefulWidget {
  const GamesListScreen({super.key});

  @override
  ConsumerState<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends ConsumerState<GamesListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  GamePlatform? _selectedPlatform;

  @override
  void initState() {
    super.initState();
    // Pre-warm Stockfish engine in background for faster game analysis
    // This significantly reduces the time to start analyzing a game
    GlobalStockfishManager.instance.preWarm();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final gamesState = ref.watch(gamesProvider);
    final filteredGames = ref.watch(filteredGamesProvider);
    final filter = ref.watch(gamesFilterProvider);

    if (!authState.isAuthenticated || authState.isGuest) {
      return const LoginRequiredView();
    }

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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('My Games'),
                  // Small sync indicator when syncing in background
                  if (gamesState.isSyncingInBackground) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
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

  Widget _buildBody(BuildContext context, GamesState gamesState, List<ChessGame> games) {
    // Show loading while initial cache load is happening
    if (gamesState.isInitialLoading || gamesState.isLoading || gamesState.isImporting) {
      return GamesLoadingView(
        isImporting: gamesState.isImporting,
        importingPlatform: gamesState.importingPlatform,
        importProgress: gamesState.importProgress,
        importTotal: gamesState.importTotal,
      );
    }

    if (!gamesState.hasGames && !gamesState.hasSavedProfiles) {
      return GamesEmptyState(onImportPressed: () => ImportSheet.show(context));
    }

    if (!gamesState.hasGames && gamesState.hasSavedProfiles) {
      return NoGamesView(onImportPressed: () => ImportSheet.show(context));
    }

    if (games.isEmpty) {
      return GamesNoResultsState(
        onClearFilters: () {
          ref.read(gamesFilterProvider.notifier).state = GamesFilter();
          _searchController.clear();
        },
      );
    }

    final filteredByPlatform = _selectedPlatform != null
        ? games.where((g) => g.platform == _selectedPlatform).toList()
        : games;

    return RefreshIndicator(
      onRefresh: () => ref.read(gamesProvider.notifier).refreshFromSavedProfiles(),
      child: CustomScrollView(
        slivers: [
          // Collapsible header with stats and quick actions
          SliverToBoxAdapter(
            child: _CollapsibleHeader(
              selectedPlatform: _selectedPlatform,
              gamesState: gamesState,
              onPlatformSelected: (platform) => setState(() => _selectedPlatform = platform),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'RECENT MATCHES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredByPlatform.length} games',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Games list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final game = filteredByPlatform[index];
                return GameCard(
                  game: game,
                  onTap: () => context.pushNamed('game-review', extra: game),
                );
              },
              childCount: filteredByPlatform.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }
}

/// Collapsible header with stats and quick actions
class _CollapsibleHeader extends StatelessWidget {
  final GamePlatform? selectedPlatform;
  final GamesState gamesState;
  final ValueChanged<GamePlatform?> onPlatformSelected;

  const _CollapsibleHeader({
    required this.selectedPlatform,
    required this.gamesState,
    required this.onPlatformSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GamesStatsBar(selectedPlatform: selectedPlatform),
        PlatformSwitcher(
          chessComUsername: gamesState.activeChessComUsername,
          lichessUsername: gamesState.activeLichessUsername,
          selectedPlatform: selectedPlatform,
          onPlatformSelected: onPlatformSelected,
        ),
        const QuickAccessButtons(),
      ],
    );
  }
}
