/// Shared types for Stockfish service (no dart:ffi dependency)

import 'dart:io';

/// Configuration for Stockfish engine
class StockfishConfig {
  /// Number of principal variations to compute (1-5)
  final int multiPv;

  /// Hash table size in MB
  final int hashSizeMb;

  /// Number of threads to use
  final int threads;

  /// Maximum search depth (0 = unlimited)
  final int maxDepth;

  const StockfishConfig({
    this.multiPv = 3,
    this.hashSizeMb = 64,
    this.threads = 4,  // Use 4 threads by default (most phones have 4+ cores)
    this.maxDepth = 20,
  });

  /// Get optimal config for mobile devices
  static StockfishConfig forMobile() {
    // Use half of available cores (leave some for UI), minimum 2, maximum 6
    final cores = Platform.numberOfProcessors;
    final threads = (cores ~/ 2).clamp(2, 6);

    return StockfishConfig(
      multiPv: 3,
      hashSizeMb: 64,  // 64MB is good for mobile
      threads: threads,
      maxDepth: 20,
    );
  }

  /// Get config for quick evaluations (lower depth)
  static StockfishConfig forQuickEval() {
    final cores = Platform.numberOfProcessors;
    final threads = (cores ~/ 2).clamp(2, 6);

    return StockfishConfig(
      multiPv: 1,
      hashSizeMb: 32,
      threads: threads,
      maxDepth: 15,
    );
  }

  StockfishConfig copyWith({
    int? multiPv,
    int? hashSizeMb,
    int? threads,
    int? maxDepth,
  }) {
    return StockfishConfig(
      multiPv: multiPv ?? this.multiPv,
      hashSizeMb: hashSizeMb ?? this.hashSizeMb,
      threads: threads ?? this.threads,
      maxDepth: maxDepth ?? this.maxDepth,
    );
  }
}

/// State of the Stockfish engine
enum StockfishState {
  uninitialized,
  initializing,
  ready,
  analyzing,
  disposed,
  error,
}
