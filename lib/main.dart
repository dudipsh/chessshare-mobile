import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/api/supabase_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_navigation.dart';
import 'core/services/app_init_service.dart';
import 'core/services/global_stockfish_manager.dart';
import 'features/analysis/services/stockfish_types.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Initialize Supabase (optional - may fail if not configured)
  await _initializeSupabase();

  // Initialize app services (database, auth, etc.)
  await AppInitService.initialize();

  // Initialize local notifications
  await _initializeNotifications();

  // Pre-initialize Stockfish in background (so it's ready when user needs it)
  _preInitializeStockfish();

  runApp(
    const ProviderScope(
      child: ChessShareApp(),
    ),
  );
}

/// Pre-initialize Stockfish engine in background
/// This makes first game analysis much faster
void _preInitializeStockfish() {
  // Stockfish only works on iOS and Android
  if (!Platform.isIOS && !Platform.isAndroid) return;

  // Run in background - don't await
  Future.delayed(const Duration(seconds: 2), () async {
    try {
      final config = StockfishConfig.forMobile();
      // Use 'shared' owner so any screen can use the pre-loaded instance
      await GlobalStockfishManager.instance.acquire('shared', config: config);
    } catch (e) {
      debugPrint('Stockfish pre-initialization failed: $e');
    }
  });
}

Future<void> _initializeNotifications() async {
  try {
    await LocalNotificationService().initialize();

    // Set up notification tap handler
    LocalNotificationService.onNotificationTap = (payload) {
      // Use navigation service to handle the tap
      NotificationNavigationService().onNotificationTapped(payload);
    };
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }
}

Future<void> _initializeSupabase() async {
  // Load Supabase credentials from environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Initialize Supabase
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      );
      // Mark Supabase as ready for queries
      SupabaseService.markReady();
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }
}
