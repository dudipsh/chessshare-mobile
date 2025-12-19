import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_database.dart';
import '../../features/auth/services/google_auth_service.dart';

/// Service responsible for initializing the app
class AppInitService {
  static bool _isInitialized = false;
  static String? _error;

  static bool get isInitialized => _isInitialized;
  static String? get error => _error;

  /// Initialize all app services
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local database
      await _initializeDatabase();

      // Initialize Google Sign-In
      await _initializeGoogleSignIn();

      // Initialize Supabase (optional - may not be configured)
      await _initializeSupabase();

      _isInitialized = true;
      debugPrint('App initialization complete');
    } catch (e) {
      _error = e.toString();
      debugPrint('App initialization error: $e');
      // Don't rethrow - app should still work with partial initialization
      _isInitialized = true;
    }
  }

  static Future<void> _initializeDatabase() async {
    try {
      // Just access the database to trigger initialization
      await LocalDatabase.database;
      debugPrint('Local database initialized');
    } catch (e) {
      debugPrint('Database initialization error: $e');
      rethrow;
    }
  }

  static Future<void> _initializeGoogleSignIn() async {
    try {
      await GoogleAuthService.initialize();
      debugPrint('Google Sign-In initialized: ${GoogleAuthService.isAvailable}');
    } catch (e) {
      debugPrint('Google Sign-In initialization error: $e');
      // Don't rethrow - app should work without Google Sign-In
    }
  }

  static Future<void> _initializeSupabase() async {
    try {
      // Check if Supabase is already initialized
      // If not configured, this will fail silently
      final _ = Supabase.instance.client;
      debugPrint('Supabase already initialized');
    } catch (e) {
      debugPrint('Supabase not configured: $e');
      // Don't rethrow - app should work without Supabase
    }
  }
}
