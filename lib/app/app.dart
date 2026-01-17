import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/local_notification_service.dart';
import '../core/notifications/notification_navigation.dart';
import '../core/services/force_update_service.dart';
import '../core/widgets/force_update_dialog.dart';
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
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationNavigation();
    _checkForUpdates();
  }

  /// Check for app updates and show dialog if needed
  Future<void> _checkForUpdates() async {
    // Wait for app to fully initialize
    await Future.delayed(const Duration(seconds: 1));

    final result = await ForceUpdateService.checkForUpdate();

    if (!mounted) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (result.status) {
      case UpdateStatus.forceUpdateRequired:
        // Force update - user cannot dismiss
        ForceUpdateDialog.showForceUpdate(context, result);
        break;
      case UpdateStatus.updateAvailable:
        // Optional update - user can dismiss
        ForceUpdateDialog.showOptionalUpdate(context, result);
        break;
      case UpdateStatus.upToDate:
      case UpdateStatus.error:
        // No action needed
        break;
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationNavigation() {
    final navService = NotificationNavigationService();

    // Listen for notification taps while app is running
    _notificationSubscription = navService.navigationStream.listen((payload) {
      debugPrint('App: Received notification tap payload: $payload');
      // Wait for next frame to ensure router is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        debugPrint('App: Navigator context available: ${context != null}');
        if (context != null) {
          NotificationNavigationService.navigateFromPayload(context, payload);
        }
      });
    });

    // Check for launch payload from cold start (app was killed)
    // Need to wait a bit for router to be ready after auth redirect
    Future.delayed(const Duration(milliseconds: 500), () {
      final launchPayload = LocalNotificationService.launchPayload;
      if (launchPayload != null) {
        debugPrint('Processing launch payload: $launchPayload');
        LocalNotificationService.launchPayload = null; // Clear it
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          NotificationNavigationService.navigateFromPayload(context, launchPayload);
        }
      }
    });
  }

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
