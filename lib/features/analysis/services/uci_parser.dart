import 'package:dartchess/dartchess.dart';

import '../models/best_move.dart';
import '../models/engine_evaluation.dart';
import '../models/engine_stats.dart';
import '../models/principal_variation.dart';

/// Result from parsing UCI info line
class UciInfoResult {
  final PrincipalVariation? pv;
  final EngineStats? stats;

  const UciInfoResult({this.pv, this.stats});
}

/// Parser for UCI protocol output from Stockfish
class UciParser {
  /// Parse a "bestmove" line
  /// Example: "bestmove e2e4 ponder e7e5"
  static BestMove? parseBestMove(String line) {
    if (!line.startsWith('bestmove')) return null;

    final parts = line.split(' ');
    if (parts.length < 2) return null;

    final moveStr = parts[1];
    if (moveStr == '(none)') return null;

    String? ponderStr;
    final ponderIndex = parts.indexOf('ponder');
    if (ponderIndex != -1 && ponderIndex + 1 < parts.length) {
      ponderStr = parts[ponderIndex + 1];
      if (ponderStr == '(none)') ponderStr = null;
    }

    try {
      return BestMove.fromUci(moveStr, ponder: ponderStr);
    } catch (e) {
      return null;
    }
  }

  /// Parse an "info" line containing PV and/or stats
  /// Example: "info depth 20 seldepth 28 multipv 1 score cp 35 nodes 1234567 nps 2500000 time 494 pv e2e4 e7e5"
  static UciInfoResult? parseInfo(String line, {Side perspective = Side.white}) {
    if (!line.startsWith('info')) return null;

    // Skip info strings (engine messages)
    if (line.contains('string')) return null;

    final tokens = _tokenize(line);

    // Parse score
    final evaluation = _parseScore(tokens, perspective);

    // Parse depth
    final depth = _getIntValue(tokens, 'depth');
    if (depth == null) return null;

    // Parse PV moves
    final pvMoves = _getPvMoves(tokens);

    // Parse stats
    final stats = _parseStats(tokens, depth);

    // Parse multipv number
    final multipv = _getIntValue(tokens, 'multipv') ?? 1;

    if (evaluation == null) {
      return UciInfoResult(stats: stats);
    }

    final pv = PrincipalVariation(
      pvNumber: multipv,
      depth: depth,
      evaluation: evaluation,
      uciMoves: pvMoves,
      stats: stats,
    );

    return UciInfoResult(pv: pv, stats: stats);
  }

  /// Check if line is a best move announcement
  static bool isBestMoveLine(String line) {
    return line.startsWith('bestmove');
  }

  /// Check if line is an info line with analysis data
  static bool isInfoLine(String line) {
    return line.startsWith('info') && !line.contains('string');
  }

  /// Tokenize UCI line into key-value pairs
  static Map<String, List<String>> _tokenize(String line) {
    final result = <String, List<String>>{};
    final parts = line.split(' ');

    String? currentKey;
    final currentValues = <String>[];

    final keywords = {
      'info',
      'depth',
      'seldepth',
      'multipv',
      'score',
      'nodes',
      'nps',
      'time',
      'pv',
      'hashfull',
      'tbhits',
      'currmove',
      'currmovenumber',
      'string',
    };

    for (final part in parts) {
      if (keywords.contains(part)) {
        // Save previous key-values
        if (currentKey != null) {
          result[currentKey] = List.from(currentValues);
        }
        currentKey = part;
        currentValues.clear();
      } else if (currentKey != null) {
        currentValues.add(part);
      }
    }

    // Save last key-values
    if (currentKey != null) {
      result[currentKey] = List.from(currentValues);
    }

    return result;
  }

  /// Parse score from tokens
  static EngineEvaluation? _parseScore(
    Map<String, List<String>> tokens,
    Side perspective,
  ) {
    final scoreValues = tokens['score'];
    if (scoreValues == null || scoreValues.isEmpty) return null;

    final scoreType = scoreValues[0];

    if (scoreType == 'cp' && scoreValues.length >= 2) {
      final cp = int.tryParse(scoreValues[1]);
      if (cp != null) {
        return EngineEvaluation.cp(cp, perspective: perspective);
      }
    } else if (scoreType == 'mate' && scoreValues.length >= 2) {
      final moves = int.tryParse(scoreValues[1]);
      if (moves != null) {
        return EngineEvaluation.mate(moves, perspective: perspective);
      }
    }

    return null;
  }

  /// Parse engine stats from tokens
  static EngineStats? _parseStats(Map<String, List<String>> tokens, int depth) {
    final nodes = _getIntValue(tokens, 'nodes');
    final nps = _getIntValue(tokens, 'nps');

    if (nodes == null || nps == null) return null;

    return EngineStats(
      depth: depth,
      selectiveDepth: _getIntValue(tokens, 'seldepth'),
      nodes: nodes,
      nodesPerSecond: nps,
      timeMs: _getIntValue(tokens, 'time'),
      hashFullPerMille: _getIntValue(tokens, 'hashfull'),
    );
  }

  /// Get PV moves from tokens
  static List<String> _getPvMoves(Map<String, List<String>> tokens) {
    return tokens['pv'] ?? [];
  }

  /// Get integer value for a token key
  static int? _getIntValue(Map<String, List<String>> tokens, String key) {
    final values = tokens[key];
    if (values == null || values.isEmpty) return null;
    return int.tryParse(values[0]);
  }
}
