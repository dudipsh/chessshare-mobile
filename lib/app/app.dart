import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/gamification/providers/gamification_provider.dart';
import '../features/gamification/widgets/gamification_listener.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

class ChessShareApp extends ConsumerStatefulWidget {
  const ChessShareApp({super.key});

  @override
  ConsumerState<ChessShareApp> createState() => _ChessShareAppState();
}

class _ChessShareAppState extends ConsumerState<ChessShareApp> {
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    // Initialize gamification when user logs in (only for Supabase users with valid UUID)
    final supabaseUser = authState.user;
    final userId = supabaseUser?.id; // Use Supabase user ID (UUID), not profile ID
    if (userId != null && userId != _lastUserId) {
      _lastUserId = userId;
      // Use addPostFrameCallback to avoid modifying state during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(gamificationProvider.notifier).initialize(userId);
      });
    } else if (userId == null && _lastUserId != null) {
      // User logged out
      _lastUserId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(gamificationProvider.notifier).clear();
      });
    }

    return MaterialApp.router(
      title: 'ChessShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeState.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return GamificationListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
