import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/games/screens/games_list_screen.dart';
import '../features/games/screens/import_screen.dart';
import '../features/analysis/screens/analysis_screen.dart';
import '../features/games/models/chess_game.dart';

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
            builder: (context, state) => const _PlaceholderScreen(title: 'Study'),
          ),
          GoRoute(
            path: '/puzzles',
            name: 'puzzles',
            builder: (context, state) => const _PlaceholderScreen(title: 'Puzzles'),
          ),
          GoRoute(
            path: '/insights',
            name: 'insights',
            builder: (context, state) => const _PlaceholderScreen(title: 'Insights'),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const _PlaceholderScreen(title: 'Profile'),
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
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Study',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: 'Puzzles',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
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
    if (location.startsWith('/puzzles')) return 2;
    if (location.startsWith('/insights')) return 3;
    if (location.startsWith('/profile')) return 4;
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
        context.goNamed('puzzles');
        break;
      case 3:
        context.goNamed('insights');
        break;
      case 4:
        context.goNamed('profile');
        break;
    }
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title\nComing Soon',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
