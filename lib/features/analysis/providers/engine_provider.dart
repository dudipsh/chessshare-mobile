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
  final bool isReady;
  final bool isAnalyzing;
  final EngineEvaluation? evaluation;
  final List<PrincipalVariation> pvLines;
  final BestMove? bestMove;
  final EngineStats? stats;
  final String? currentFen;
  final String? error;
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

  PrincipalVariation? get bestLine =>
      pvLines.isNotEmpty ? pvLines.first : null;

  double get evaluationBarPosition => evaluation?.normalizedScore ?? 0.5;
}

/// Manages Stockfish engine analysis
class EngineAnalysisNotifier extends StateNotifier<EngineAnalysisState> {
  StockfishService? _service;
  StreamSubscription<String>? _outputSubscription;
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 150);

  EngineAnalysisNotifier() : super(const EngineAnalysisState());

  /// Initialize the engine
  Future<void> initialize() async {
    if (state.isReady || _service != null) return;

    try {
      _service = StockfishService();
      await _service!.initialize();

      _outputSubscription = _service!.outputStream.listen(_handleOutput);

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
    if (!state.isReady || _service == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _startAnalysis(fen, moves: moves);
    });
  }

  Future<void> _startAnalysis(String fen, {List<String>? moves}) async {
    if (!state.isReady || _service == null) return;

    // Stop any current analysis
    if (state.isAnalyzing) {
      _service!.stop();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Clear previous results
    state = state.copyWith(
      isAnalyzing: true,
      currentFen: fen,
      pvLines: [],
      clearEvaluation: true,
      clearBestMove: true,
    );

    // Set position and start analysis
    _service!.setPosition(fen, moves);
    _service!.startAnalysis();
  }

  /// Stop current analysis
  Future<void> stopAnalysis() async {
    _debounceTimer?.cancel();
    if (_service != null && state.isAnalyzing) {
      await _service!.stop();
    }
    state = state.copyWith(isAnalyzing: false);
  }

  void _handleOutput(String line) {
    if (!mounted) return;

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

    final index = pvLines.indexWhere((p) => p.pvNumber == pv.pvNumber);
    if (index != -1) {
      pvLines[index] = pv;
    } else {
      pvLines.add(pv);
    }

    pvLines.sort((a, b) => a.pvNumber.compareTo(b.pvNumber));
    final evaluation = pvLines.isNotEmpty ? pvLines.first.evaluation : null;

    state = state.copyWith(
      pvLines: pvLines,
      evaluation: evaluation,
    );
  }

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
    _service?.dispose();
    super.dispose();
  }
}

// Main provider - creates a single instance
final engineAnalysisProvider =
    StateNotifierProvider<EngineAnalysisNotifier, EngineAnalysisState>((ref) {
  return EngineAnalysisNotifier();
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

final engineIsReadyProvider = Provider<bool>((ref) {
  return ref.watch(engineAnalysisProvider).isReady;
});
