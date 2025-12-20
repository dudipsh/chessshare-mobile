import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/games/screens/games_list_screen.dart';
import '../features/games/screens/import_screen.dart';
import '../features/analysis/screens/analysis_screen.dart';
import '../features/games/models/chess_game.dart';
import '../features/games/screens/game_review_screen.dart';
import '../features/insights/screens/insights_screen.dart';
import '../features/puzzles/models/puzzle.dart';
import '../features/puzzles/screens/puzzle_screen.dart';
import '../features/puzzles/screens/puzzles_list_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/study/screens/study_screen.dart';
import '../features/study/screens/study_board_screen.dart';
import '../features/study/models/study_board.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/games',
    routes: [
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

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'My Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Study',
          ),
          NavigationDestination(
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
    if (location.startsWith('/study')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed('games');
        break;
      case 1:
        context.goNamed('study');
        break;
      case 2:
        context.goNamed('profile');
        break;
    }
  }
}

