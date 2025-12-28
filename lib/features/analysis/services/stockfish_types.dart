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

  /// Skill level (0-20, where 0 is weakest and 20 is strongest)
  /// This makes Stockfish intentionally play weaker moves at lower levels
  final int? skillLevel;

  const StockfishConfig({
    this.multiPv = 3,
    this.hashSizeMb = 64,
    this.threads = 4,  // Use 4 threads by default (most phones have 4+ cores)
    this.maxDepth = 20,
    this.skillLevel,
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
    int? skillLevel,
  }) {
    return StockfishConfig(
      multiPv: multiPv ?? this.multiPv,
      hashSizeMb: hashSizeMb ?? this.hashSizeMb,
      threads: threads ?? this.threads,
      maxDepth: maxDepth ?? this.maxDepth,
      skillLevel: skillLevel ?? this.skillLevel,
    );
  }

  /// Get config for playing against engine at a specific level
  /// Level 1 = very weak beginner, Level 20 = full strength
  static StockfishConfig forPlaying({required int level}) {
    final cores = Platform.numberOfProcessors;
    final threads = (cores ~/ 2).clamp(2, 4);

    return StockfishConfig(
      multiPv: 1,
      hashSizeMb: 32,
      threads: threads,
      maxDepth: 20,  // Keep depth high, skill level controls strength
      skillLevel: level.clamp(0, 20),
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
