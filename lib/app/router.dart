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
          final puzzle = state.extra as Puzzle;
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
    // Watch daily puzzle state for badge indicator
    final dailyPuzzleAvailable = ref.watch(isDailyPuzzleAvailableProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'My Games',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: dailyPuzzleAvailable,
              child: const Icon(Icons.extension_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: dailyPuzzleAvailable,
              child: const Icon(Icons.extension),
            ),
            label: 'Daily',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Study',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
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

/// Notifier that triggers router refresh when auth state changes
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
