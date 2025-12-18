import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/best_move.dart';
import '../models/engine_evaluation.dart';
import '../models/engine_stats.dart';
import '../models/principal_variation.dart';
import '../services/stockfish_service.dart';
import '../services/uci_parser.dart';

/// State of engine analysis
class EngineAnalysisState {
  /// Whether the engine is initialized and ready
  final bool isReady;

  /// Whether analysis is currently running
  final bool isAnalyzing;

  /// Current evaluation (from best PV)
  final EngineEvaluation? evaluation;

  /// All principal variations
  final List<PrincipalVariation> pvLines;

  /// Best move (when analysis completes)
  final BestMove? bestMove;

  /// Latest engine statistics
  final EngineStats? stats;

  /// Current position being analyzed
  final String? currentFen;

  /// Error message if any
  final String? error;

  /// Engine configuration
  final StockfishConfig config;

  const EngineAnalysisState({
    this.isReady = false,
    this.isAnalyzing = false,
    this.evaluation,
    this.pvLines = const [],
    this.bestMove,
    this.stats,
    this.currentFen,
    this.error,
    this.config = const StockfishConfig(),
  });

  EngineAnalysisState copyWith({
    bool? isReady,
    bool? isAnalyzing,
    EngineEvaluation? evaluation,
    List<PrincipalVariation>? pvLines,
    BestMove? bestMove,
    EngineStats? stats,
    String? currentFen,
    String? error,
    StockfishConfig? config,
    bool clearEvaluation = false,
    bool clearBestMove = false,
  }) {
    return EngineAnalysisState(
      isReady: isReady ?? this.isReady,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      evaluation: clearEvaluation ? null : (evaluation ?? this.evaluation),
      pvLines: pvLines ?? this.pvLines,
      bestMove: clearBestMove ? null : (bestMove ?? this.bestMove),
      stats: stats ?? this.stats,
      currentFen: currentFen ?? this.currentFen,
      error: error,
      config: config ?? this.config,
    );
  }

  /// Get the best line (PV1)
  PrincipalVariation? get bestLine =>
      pvLines.isNotEmpty ? pvLines.first : null;

  /// Get evaluation bar position (0-1, 0.5 = equal)
  double get evaluationBarPosition => evaluation?.normalizedScore ?? 0.5;
}

/// Manages Stockfish engine analysis
class EngineAnalysisNotifier extends StateNotifier<EngineAnalysisState> {
  final StockfishService _service;
  StreamSubscription<String>? _outputSubscription;
  Timer? _debounceTimer;

  /// Debounce duration for position changes
  static const _debounceDuration = Duration(milliseconds: 300);

  EngineAnalysisNotifier({StockfishService? service})
      : _service = service ?? StockfishService(),
        super(const EngineAnalysisState());

  /// Initialize the engine
  Future<void> initialize() async {
    if (state.isReady) return;

    try {
      await _service.initialize();

      _outputSubscription = _service.outputStream.listen(_handleOutput);

      state = state.copyWith(isReady: true, error: null);
    } catch (e) {
      state = state.copyWith(
        isReady: false,
        error: 'Failed to initialize engine: $e',
      );
    }
  }

  /// Analyze a position
  void analyzePosition(String fen, {List<String>? moves}) {
    if (!state.isReady) return;

    // Debounce rapid position changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      await _startAnalysis(fen, moves: moves);
    });
  }

  /// Start analysis immediately without debouncing
  Future<void> _startAnalysis(String fen, {List<String>? moves}) async {
    if (!state.isReady) return;

    // Stop any current analysis
    await stopAnalysis();

    // Clear previous results
    state = state.copyWith(
      isAnalyzing: true,
      currentFen: fen,
      pvLines: [],
      clearEvaluation: true,
      clearBestMove: true,
    );

    // Set position and start analysis
    _service.setPosition(fen, moves);
    _service.startAnalysis();
  }

  /// Stop current analysis
  Future<void> stopAnalysis() async {
    _debounceTimer?.cancel();
    await _service.stop();
    state = state.copyWith(isAnalyzing: false);
  }

  /// Update engine configuration
  Future<void> updateConfig(StockfishConfig config) async {
    await _service.updateConfig(config);
    state = state.copyWith(config: config);

    // Restart analysis if one was running
    if (state.currentFen != null) {
      await _startAnalysis(state.currentFen!);
    }
  }

  /// Set number of PV lines
  Future<void> setMultiPv(int count) async {
    final clampedCount = count.clamp(1, 5);
    await updateConfig(state.config.copyWith(multiPv: clampedCount));
  }

  /// Convert UCI moves to SAN for display
  List<PrincipalVariation> _enrichPvLines(
    List<PrincipalVariation> pvLines,
    String fen,
  ) {
    try {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      return pvLines.map((pv) => pv.withSanMoves(position)).toList();
    } catch (e) {
      return pvLines;
    }
  }

  void _handleOutput(String line) {
    // Parse info lines
    if (UciParser.isInfoLine(line)) {
      final perspective = _getSideToMove(state.currentFen);
      final result = UciParser.parseInfo(line, perspective: perspective);

      if (result != null) {
        if (result.pv != null) {
          _updatePvLine(result.pv!);
        }
        if (result.stats != null) {
          state = state.copyWith(stats: result.stats);
        }
      }
    }

    // Parse bestmove
    if (UciParser.isBestMoveLine(line)) {
      final bestMove = UciParser.parseBestMove(line);

      // Enrich PV lines with SAN moves
      final enrichedPvLines = state.currentFen != null
          ? _enrichPvLines(state.pvLines, state.currentFen!)
          : state.pvLines;

      state = state.copyWith(
        isAnalyzing: false,
        bestMove: bestMove,
        pvLines: enrichedPvLines,
      );
    }
  }

  void _updatePvLine(PrincipalVariation pv) {
    final pvLines = List<PrincipalVariation>.from(state.pvLines);

    // Find and replace or add PV line
    final index = pvLines.indexWhere((p) => p.pvNumber == pv.pvNumber);
    if (index != -1) {
      pvLines[index] = pv;
    } else {
      pvLines.add(pv);
    }

    // Sort by PV number and update evaluation from best line
    pvLines.sort((a, b) => a.pvNumber.compareTo(b.pvNumber));

    final evaluation = pvLines.isNotEmpty ? pvLines.first.evaluation : null;

    state = state.copyWith(
      pvLines: pvLines,
      evaluation: evaluation,
    );
  }

  Side _getSideToMove(String? fen) {
    if (fen == null) return Side.white;
    try {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      return position.turn;
    } catch (e) {
      return Side.white;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _outputSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}

// Providers
final engineServiceProvider = Provider<StockfishService>((ref) {
  final service = StockfishService();
  ref.onDispose(() => service.dispose());
  return service;
});

final engineAnalysisProvider =
    StateNotifierProvider<EngineAnalysisNotifier, EngineAnalysisState>((ref) {
  final service = ref.watch(engineServiceProvider);
  final notifier = EngineAnalysisNotifier(service: service);
  return notifier;
});

// Convenience providers
final engineEvaluationProvider = Provider<EngineEvaluation?>((ref) {
  return ref.watch(engineAnalysisProvider).evaluation;
});

final enginePvLinesProvider = Provider<List<PrincipalVariation>>((ref) {
  return ref.watch(engineAnalysisProvider).pvLines;
});

final engineIsAnalyzingProvider = Provider<bool>((ref) {
  return ref.watch(engineAnalysisProvider).isAnalyzing;
});

final engineStatsProvider = Provider<EngineStats?>((ref) {
  return ref.watch(engineAnalysisProvider).stats;
});
