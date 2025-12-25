import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/api/supabase_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/services/app_init_service.dart';
import 'core/services/global_stockfish_manager.dart';

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
  if (!Platform.isIOS && !Platform.isAndroid) {
    debugPrint('Stockfish not supported on this platform');
    return;
  }

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

    // Set up notification tap handler
    LocalNotificationService.onNotificationTap = (payload) {
      debugPrint('Handling notification tap: $payload');
      // Navigation will be handled by the app when it gets the payload
      // The router will read this and navigate accordingly
      _pendingNotificationPayload = payload;
    };

    debugPrint('Local notifications initialized');
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }
}

/// Pending notification payload for navigation
String? _pendingNotificationPayload;

/// Get and clear pending notification payload
String? consumePendingNotificationPayload() {
  final payload = _pendingNotificationPayload;
  _pendingNotificationPayload = null;
  return payload;
}

Future<void> _initializeSupabase() async {
  // Load Supabase credentials from environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Initialize Supabase
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      // Debug: Log key info (first 20 chars only for security)
      debugPrint('Supabase init - URL: $supabaseUrl');
      if (supabaseKey.length >= 20) {
        debugPrint('Supabase init - Key starts with: ${supabaseKey.substring(0, 20)}...');
      }
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
    debugPrint('Missing: ${supabaseUrl.isEmpty ? "SUPABASE_URL" : ""} ${supabaseKey.isEmpty ? "SUPABASE_ANON_KEY" : ""}');
  }
}
