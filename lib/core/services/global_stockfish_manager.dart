import 'dart:async';

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
    debugPrint('GlobalStockfish: $ownerId requesting acquisition');

    // If another owner has it, release first
    if (_stockfish != null && _currentOwner != null && _currentOwner != ownerId) {
      debugPrint('GlobalStockfish: Releasing from $_currentOwner for $ownerId');
      await release(_currentOwner!);
    }

    // If we already have it for this owner, just return it
    if (_stockfish != null && _currentOwner == ownerId) {
      debugPrint('GlobalStockfish: Already owned by $ownerId');
      // Update config if needed
      if (config != null) {
        await _stockfish!.updateConfig(config);
      }
      return _stockfish!;
    }

    // Wait if initialization is in progress
    if (_initCompleter != null) {
      debugPrint('GlobalStockfish: Waiting for current initialization...');
      await _initCompleter!.future;
    }

    // Create new instance
    _initCompleter = Completer<void>();
    try {
      debugPrint('GlobalStockfish: Creating new instance for $ownerId');
      _stockfish = StockfishService(config: config);
      await _stockfish!.initialize();
      _currentOwner = ownerId;
      debugPrint('GlobalStockfish: Acquired by $ownerId');
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
  Future<void> release(String ownerId) async {
    if (_currentOwner != ownerId) {
      debugPrint('GlobalStockfish: $ownerId tried to release but owner is $_currentOwner');
      return;
    }

    debugPrint('GlobalStockfish: Releasing from $ownerId');
    await _stockfish?.dispose();
    _stockfish = null;
    _currentOwner = null;
  }

  /// Force release and dispose (use carefully)
  Future<void> forceRelease() async {
    debugPrint('GlobalStockfish: Force releasing from $_currentOwner');
    await _stockfish?.dispose();
    _stockfish = null;
    _currentOwner = null;
  }

  /// Check if a specific owner has the engine
  bool isOwnedBy(String ownerId) => _currentOwner == ownerId;
}
