/// Shared types for Stockfish service (no dart:ffi dependency)

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
    this.hashSizeMb = 32,
    this.threads = 1,
    this.maxDepth = 22,
  });

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
