import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/games/screens/games_list_screen.dart';
import '../features/games/screens/import_screen.dart';
import '../features/analysis/screens/analysis_screen.dart';
import '../features/games/models/chess_game.dart';
import '../features/games/screens/game_review_screen.dart';
import '../features/insights/screens/insights_screen.dart';
import '../features/puzzles/models/puzzle.dart';
import '../features/puzzles/providers/daily_puzzle_provider.dart';
import '../features/puzzles/screens/daily_puzzle_screen.dart';
import '../features/puzzles/screens/puzzle_screen.dart';
import '../features/puzzles/screens/puzzles_list_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/study/screens/study_screen.dart';
import '../features/study/screens/study_board_screen.dart';
import '../features/study/models/study_board.dart';

/// Global navigator key for showing dialogs from anywhere
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _AuthStateNotifier(ref),
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final isGuest = authState.isGuest;
      final location = state.matchedLocation;

      // While loading, stay on splash
      if (isLoading) {
        if (location != '/splash') {
          return '/splash';
        }
        return null;
      }

      // After loading is done
      if (location == '/splash') {
        // Redirect based on auth state
        if (isAuthenticated && !isGuest) {
          return '/study';
        } else {
          return '/login';
        }
      }

      // If on login but authenticated, go to games
      if (location == '/login' && isAuthenticated && !isGuest) {
        return '/games';
      }

      // If trying to access protected routes without auth, go to login
      final protectedRoutes = ['/games', '/study', '/profile', '/puzzles', '/insights'];
      if (protectedRoutes.any((r) => location.startsWith(r))) {
        if (!isAuthenticated || isGuest) {
          return '/login';
        }
      }

      return null;
    },
    routes: [
      // Splash screen (shown while auth state is loading)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Import routes (outside shell - no bottom nav)
      GoRoute(
        path: '/import/:platform',
        name: 'import',
        builder: (context, state) {
          final platform = state.pathParameters['platform'] ?? 'chesscom';
          return ImportScreen(platform: platform);
        },
      ),

      // Analysis route (outside shell - no bottom nav)
      GoRoute(
        path: '/analysis',
        name: 'analysis',
        builder: (context, state) {
          final game = state.extra as ChessGame;
          return AnalysisScreen(game: game);
        },
      ),

      // Puzzle solving route (outside shell - no bottom nav)
      GoRoute(
        path: '/puzzle',
        name: 'puzzle',
        builder: (context, state) {
          final extra = state.extra;
          // Support both single puzzle and puzzle with list context
          if (extra is Map<String, dynamic>) {
            final puzzle = extra['puzzle'] as Puzzle;
            final puzzlesList = extra['puzzlesList'] as List<Puzzle>?;
            final currentIndex = extra['currentIndex'] as int?;
            return PuzzleScreen(
              puzzle: puzzle,
              puzzlesList: puzzlesList,
              currentIndex: currentIndex,
            );
          }
          // Fallback for single puzzle
          final puzzle = extra as Puzzle;
          return PuzzleScreen(puzzle: puzzle);
        },
      ),

      // Study board route (outside shell - no bottom nav)
      GoRoute(
        path: '/study-board',
        name: 'study-board',
        builder: (context, state) {
          final board = state.extra as StudyBoard;
          return StudyBoardScreen(board: board);
        },
      ),

      // Game review route (outside shell - no bottom nav)
      GoRoute(
        path: '/game-review',
        name: 'game-review',
        builder: (context, state) {
          final game = state.extra as ChessGame;
          return GameReviewScreen(game: game);
        },
      ),

      // Puzzles route (outside shell - accessed from My Games)
      GoRoute(
        path: '/puzzles',
        name: 'puzzles',
        builder: (context, state) => const PuzzlesListScreen(),
      ),

      // Insights route (outside shell - accessed from My Games)
      GoRoute(
        path: '/insights',
        name: 'insights',
        builder: (context, state) => const InsightsScreen(),
      ),

      // User profile route (view another user's profile)
      GoRoute(
        path: '/user/:userId',
        name: 'user-profile',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final userName = state.uri.queryParameters['name'];
          final userAvatar = state.uri.queryParameters['avatar'];
          return ProfileScreen(
            viewUserId: userId,
            viewUserName: userName,
            viewUserAvatar: userAvatar,
          );
        },
      ),

      // Main app routes with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/games',
            name: 'games',
            builder: (context, state) => const GamesListScreen(),
          ),
          GoRoute(
            path: '/daily-puzzle',
            name: 'daily-puzzle',
            builder: (context, state) => const DailyPuzzleScreen(),
          ),
          GoRoute(
            path: '/study',
            name: 'study',
            builder: (context, state) => const StudyScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyPuzzleAvailable = ref.watch(isDailyPuzzleAvailableProvider);
    final selectedIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          top: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? Colors.black : Colors.white).withValues(alpha: 0),
              (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
              isDark ? Colors.black : Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.sports_esports_outlined,
                selectedIcon: Icons.sports_esports,
                label: 'Games',
                isSelected: selectedIndex == 0,
                onTap: () => _onItemTapped(0, context),
                isDark: isDark,
              ),
              _NavItem(
                icon: Icons.extension_outlined,
                selectedIcon: Icons.extension,
                label: 'Daily',
                isSelected: selectedIndex == 1,
                onTap: () => _onItemTapped(1, context),
                isDark: isDark,
                showBadge: dailyPuzzleAvailable,
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book,
                label: 'Study',
                isSelected: selectedIndex == 2,
                onTap: () => _onItemTapped(2, context),
                isDark: isDark,
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                isSelected: selectedIndex == 3,
                onTap: () => _onItemTapped(3, context),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/games')) return 0;
    if (location.startsWith('/daily-puzzle')) return 1;
    if (location.startsWith('/study')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed('games');
        break;
      case 1:
        context.goNamed('daily-puzzle');
        break;
      case 2:
        context.goNamed('study');
        break;
      case 3:
        context.goNamed('profile');
        break;
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final bool showBadge;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    key: ValueKey(isSelected),
                    size: 24,
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Animated label that appears when selected
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notifier that triggers router refresh when auth state changes
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
