import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
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
  GamePlatform? _selectedPlatform; // null = show all

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

    // Show login required screen for non-authenticated users
    if (!authState.isAuthenticated || authState.isGuest) {
      return _buildLoginRequiredScreen(context);
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
    // Show loading/importing state
    if (gamesState.isLoading || gamesState.isImporting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (gamesState.isImporting) ...[
              const SizedBox(height: 16),
              Text(
                'Importing from ${gamesState.importingPlatform}...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (gamesState.importTotal > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${gamesState.importProgress}/${gamesState.importTotal}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ],
        ),
      );
    }

    // Show empty state if no games and no saved profiles
    if (!gamesState.hasGames && !gamesState.hasSavedProfiles) {
      return GamesEmptyState(
        onImportPressed: () => ImportSheet.show(context),
      );
    }

    // Show empty state with "no games found" if profiles exist but no games
    if (!gamesState.hasGames && gamesState.hasSavedProfiles) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No games found'),
            const SizedBox(height: 8),
            Text(
              'Try importing games or check your username',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ImportSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Import Games'),
            ),
          ],
        ),
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

    // Filter games by selected platform if both platforms are available
    final hasMultiplePlatforms =
        gamesState.activeChessComUsername != null && gamesState.activeLichessUsername != null;
    final filteredByPlatform = _selectedPlatform != null
        ? games.where((g) => g.platform == _selectedPlatform).toList()
        : games;

    // Show games list with stats header
    return Column(
      children: [
        const GamesStatsBar(),
        // Platform switcher when user has multiple accounts
        if (hasMultiplePlatforms) _buildPlatformSwitcher(context, gamesState),
        // Quick access buttons for Puzzles and Insights
        _buildQuickAccess(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(gamesProvider.notifier).refreshFromSavedProfiles();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredByPlatform.length,
              itemBuilder: (context, index) {
                final game = filteredByPlatform[index];
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

  Widget _buildPlatformSwitcher(BuildContext context, GamesState gamesState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _PlatformChip(
            label: 'All',
            isSelected: _selectedPlatform == null,
            isDark: isDark,
            onTap: () => setState(() => _selectedPlatform = null),
          ),
          const SizedBox(width: 8),
          _PlatformChip(
            label: gamesState.activeChessComUsername ?? 'Chess.com',
            icon: '♟',
            isSelected: _selectedPlatform == GamePlatform.chesscom,
            isDark: isDark,
            onTap: () => setState(() => _selectedPlatform = GamePlatform.chesscom),
          ),
          const SizedBox(width: 8),
          _PlatformChip(
            label: gamesState.activeLichessUsername ?? 'Lichess',
            icon: '♞',
            isSelected: _selectedPlatform == GamePlatform.lichess,
            isDark: isDark,
            onTap: () => setState(() => _selectedPlatform = GamePlatform.lichess),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequiredScreen(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in to view your games',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Import and analyze your Chess.com and Lichess games.\nTrack your progress and improve your play.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.goNamed('login'),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildQuickAccess(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickAccessButton(
              icon: Icons.extension,
              label: 'My Puzzles',
              color: Colors.orange,
              isDark: isDark,
              onTap: () => context.pushNamed('puzzles'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAccessButton(
              icon: Icons.insights,
              label: 'Insights',
              color: Colors.blue,
              isDark: isDark,
              onTap: () => context.pushNamed('insights'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.2)
          : (isDark ? Colors.white10 : Colors.grey.shade200),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(
                  icon!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
