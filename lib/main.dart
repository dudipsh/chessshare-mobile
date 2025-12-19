import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/api/supabase_service.dart';
import 'core/services/app_init_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (optional - may fail if not configured)
  await _initializeSupabase();

  // Initialize app services (database, auth, etc.)
  await AppInitService.initialize();

  runApp(
    const ProviderScope(
      child: ChessShareApp(),
    ),
  );
}

Future<void> _initializeSupabase() async {
  // Production Supabase credentials (fallback if not provided via dart-define)
  // NOTE: Using direct Supabase URL instead of custom domain (api.chessshare.com)
  // because custom domains may have different CORS/auth settings for mobile vs web
  const productionUrl = 'https://xnczyeqqgkzlbqrplsdg.supabase.co';
  const productionKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhuY3p5ZXFxZ2t6bGJxcnBsc2RnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0NzQ3NDYsImV4cCI6MjA1ODA1MDc0Nn0.pZZJ9QT-LKtzAM2d1K3-LqqKS18GrFlbhH62Bt9rL_k';

  // Use dart-define values if provided, otherwise use production defaults
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
