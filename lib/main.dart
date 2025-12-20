import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/api/supabase_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/services/app_init_service.dart';
import 'core/services/global_stockfish_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // Run in background - don't await
  Future.delayed(const Duration(seconds: 2), () async {
    try {
      debugPrint('Pre-initializing Stockfish engine...');
      // Use 'shared' owner so any screen can use the pre-loaded instance
      await GlobalStockfishManager.instance.acquire('shared');
      debugPrint('Stockfish engine pre-initialized successfully');
    } catch (e) {
      debugPrint('Stockfish pre-initialization failed (will retry on first use): $e');
    }
  });
}

Future<void> _initializeNotifications() async {
  try {
    await LocalNotificationService().initialize();
    debugPrint('Local notifications initialized');
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }
}

Future<void> _initializeSupabase() async {
  // Production Supabase credentials
  // Using direct Supabase URL (custom domain api.chessshare.com has issues)
  const productionUrl = 'https://xnczyeqqgkzlbqrplsdg.supabase.co';
  const productionKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhuY3p5ZXFxZ2t6bGJxcnBsc2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0NzQ3NDYsImV4cCI6MjA1ODA1MDc0Nn0.pZZJ9QT-LKtzAM2d1K3-LqqKS18GrFlbhH62Bt9rL_k';

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: productionUrl,
  );
  const supabaseKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: productionKey,
  );

  // Initialize Supabase
  if (supabaseUrl.isNotEmpty && !supabaseUrl.contains('YOUR_')) {
    try {
      // Debug: Log key info (first 20 chars only for security)
      debugPrint('Supabase init - URL: $supabaseUrl');
      debugPrint('Supabase init - Key starts with: ${supabaseKey.substring(0, 20)}...');
      debugPrint('Supabase init - Key length: ${supabaseKey.length}');

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
      debugPrint('Supabase initialized with: $supabaseUrl');
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  } else {
    debugPrint('Supabase not configured - running in offline mode');
  }
}
