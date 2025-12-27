import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/analysis/services/stockfish_service.dart';

/// Global singleton manager for Stockfish engine
/// Ensures only one instance exists at a time across the app
class GlobalStockfishManager {
  static GlobalStockfishManager? _instance;
  static GlobalStockfishManager get instance {
    _instance ??= GlobalStockfishManager._();
    return _instance!;
  }

  GlobalStockfishManager._();

  StockfishService? _stockfish;
  String? _currentOwner;
  Completer<void>? _initCompleter;
  bool _isPreWarming = false;

  /// Get the current Stockfish service (may be null if not acquired)
  StockfishService? get stockfish => _stockfish;

  /// Check if Stockfish is currently in use
  bool get isInUse => _stockfish != null && _currentOwner != null;

  /// Current owner ID
  String? get currentOwner => _currentOwner;

  /// Acquire Stockfish for exclusive use
  /// [ownerId] identifies who is using the engine (for debugging)
  /// [config] optional configuration for the engine
  /// Returns the StockfishService instance
  Future<StockfishService> acquire(
    String ownerId, {
    StockfishConfig? config,
  }) async {
    // If another owner has it, release first
    if (_stockfish != null && _currentOwner != null && _currentOwner != ownerId) {
      await release(_currentOwner!);
    }

    // If we already have it for this owner, just return it
    if (_stockfish != null && _currentOwner == ownerId) {
      // Update config if needed
      if (config != null) {
        await _stockfish!.updateConfig(config);
      }
      return _stockfish!;
    }

    // Wait if initialization is in progress
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }

    // Create new instance
    _initCompleter = Completer<void>();
    try {
      _stockfish = StockfishService(config: config);
      await _stockfish!.initialize();
      _currentOwner = ownerId;
      _initCompleter!.complete();
      return _stockfish!;
    } catch (e) {
      debugPrint('GlobalStockfish: Failed to acquire - $e');
      _stockfish = null;
      _currentOwner = null;
      _initCompleter!.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  /// Release Stockfish from current owner
  /// Note: 'shared' owner is never released to allow reuse across screens
  Future<void> release(String ownerId) async {
    // Don't release 'shared' owner - keep it alive for reuse
    if (ownerId == 'shared') return;
    if (_currentOwner != ownerId) return;

    await _stockfish?.dispose();
    _stockfish = null;
    _currentOwner = null;
  }

  /// Force release and dispose (use carefully)
  Future<void> forceRelease() async {
    await _stockfish?.dispose();
    _stockfish = null;
    _currentOwner = null;
  }

  /// Check if a specific owner has the engine
  bool isOwnedBy(String ownerId) => _currentOwner == ownerId;

  /// Whether the engine is currently pre-warming
  bool get isPreWarming => _isPreWarming;

  /// Whether the engine is ready (pre-warmed or acquired)
  bool get isReady => _stockfish != null && _currentOwner != null;

  /// Pre-warm the engine in background for faster analysis start
  /// Call this when user navigates to games list screen
  /// Uses 'shared' owner so it can be reused by game analysis
  Future<void> preWarm() async {
    // Skip if already running or pre-warming
    if (_stockfish != null || _isPreWarming) return;

    _isPreWarming = true;

    try {
      // Get optimal thread count based on CPU cores
      final cores = Platform.numberOfProcessors;
      final threads = (cores ~/ 2).clamp(2, 8);

      // Pre-warm with shared owner and optimal config for analysis
      await acquire(
        'shared',
        config: StockfishConfig(
          multiPv: 1,
          hashSizeMb: 32,
          threads: threads,
          maxDepth: 14,
        ),
      );
    } catch (e) {
      debugPrint('GlobalStockfish: Pre-warm failed - $e');
    } finally {
      _isPreWarming = false;
    }
  }
}
