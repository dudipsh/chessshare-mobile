import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for communicating with the Review API server
/// Handles game reviews and puzzle extraction
class ReviewApiService {
  static String get baseUrl {
    // Use local URL in debug mode, production otherwise
    if (kDebugMode) {
      return dotenv.env['REVIEW_API_URL_LOCAL'] ?? 'http://192.168.1.232:3001';
    }
    return dotenv.env['REVIEW_API_URL'] ??
        'https://chessshare-review-api-production.up.railway.app';
  }

  /// Get authorization headers with Supabase JWT
  static Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    return {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Check if the API is healthy and ready
  static Future<HealthCheckResult> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HealthCheckResult(
          isHealthy: data['status'] == 'healthy',
          stockfishStatus: data['stockfish'] ?? 'unknown',
          activeAnalyses: data['activeAnalyses'] ?? 0,
          queueLength: data['queueLength'] ?? 0,
        );
      }
      return HealthCheckResult(isHealthy: false);
    } catch (e) {
      debugPrint('ReviewApiService: Health check failed: $e');
      return HealthCheckResult(isHealthy: false, error: e.toString());
    }
  }

  /// Start game review with SSE streaming
  /// Returns a stream of [ReviewEvent] objects
  static Stream<ReviewEvent> reviewGame({
    required String pgn,
    required String playerColor,
    String? gameId,
    String? platform,
    int? depth,
  }) async* {
    final headers = await _getHeaders();

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/v1/review'),
    );

    request.headers.addAll(headers);
    request.body = jsonEncode({
      'pgn': pgn,
      'playerColor': playerColor,
      if (gameId != null) 'gameId': gameId,
      if (platform != null) 'platform': platform,
      if (depth != null) 'options': {'depth': depth},
    });

    debugPrint('ReviewApiService: Starting game review...');

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode == 401) {
        throw ReviewApiException(
          'Authentication required',
          code: 'AUTH_REQUIRED',
        );
      }

      if (response.statusCode == 429) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        throw RateLimitException(
          data['message'] ?? 'Rate limit exceeded',
          resetAt: data['resetAt'] != null
              ? DateTime.parse(data['resetAt'])
              : null,
        );
      }

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw ReviewApiException(
          'Failed to start review: ${response.statusCode}',
          body: body,
        );
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete lines
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data.isNotEmpty && data != '[DONE]') {
              try {
                final json = jsonDecode(data);
                yield ReviewEvent.fromJson(json);
              } catch (e) {
                debugPrint('ReviewApiService: Failed to parse event: $e');
              }
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Analyze a single position
  static Future<PositionAnalysis> analyzePosition({
    required String fen,
    int? depth,
  }) async {
    final headers = await _getHeaders();
    // Remove Accept header for JSON response
    headers['Accept'] = 'application/json';

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/review/position'),
      headers: headers,
      body: jsonEncode({
        'fen': fen,
        if (depth != null) 'depth': depth,
      }),
    );

    if (response.statusCode == 401) {
      throw ReviewApiException('Authentication required', code: 'AUTH_REQUIRED');
    }

    if (response.statusCode != 200) {
      throw ReviewApiException(
        'Position analysis failed: ${response.statusCode}',
        body: response.body,
      );
    }

    return PositionAnalysis.fromJson(jsonDecode(response.body));
  }

  /// Extract puzzles from a game
  static Future<PuzzleExtractionResult> extractPuzzles({
    required String pgn,
    required String playerColor,
    String? reviewId,
    int? gameRating,
    String? openingName,
  }) async {
    final headers = await _getHeaders();
    headers['Accept'] = 'application/json';

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/puzzles/extract'),
      headers: headers,
      body: jsonEncode({
        'pgn': pgn,
        'playerColor': playerColor,
        if (reviewId != null) 'reviewId': reviewId,
        if (gameRating != null) 'gameRating': gameRating,
        if (openingName != null) 'openingName': openingName,
      }),
    );

    if (response.statusCode == 401) {
      throw ReviewApiException('Authentication required', code: 'AUTH_REQUIRED');
    }

    if (response.statusCode == 429) {
      final data = jsonDecode(response.body);
      throw RateLimitException(
        data['message'] ?? 'Rate limit exceeded',
        resetAt: data['resetAt'] != null
            ? DateTime.parse(data['resetAt'])
            : null,
      );
    }

    if (response.statusCode != 200) {
      throw ReviewApiException(
        'Puzzle extraction failed: ${response.statusCode}',
        body: response.body,
      );
    }

    return PuzzleExtractionResult.fromJson(jsonDecode(response.body));
  }

  /// Generate solution sequence for a puzzle
  static Future<PuzzleSolution> generateSolution({
    required String fen,
    required String bestMove,
    bool isPositivePuzzle = false,
  }) async {
    final headers = await _getHeaders();
    headers['Accept'] = 'application/json';

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/puzzles/solution'),
      headers: headers,
      body: jsonEncode({
        'fen': fen,
        'bestMove': bestMove,
        'isPositivePuzzle': isPositivePuzzle,
      }),
    );

    if (response.statusCode == 401) {
      throw ReviewApiException('Authentication required', code: 'AUTH_REQUIRED');
    }

    if (response.statusCode != 200) {
      throw ReviewApiException(
        'Solution generation failed: ${response.statusCode}',
        body: response.body,
      );
    }

    return PuzzleSolution.fromJson(jsonDecode(response.body));
  }
}

// === Exceptions ===

class ReviewApiException implements Exception {
  final String message;
  final String? body;
  final String? code;

  ReviewApiException(this.message, {this.body, this.code});

  @override
  String toString() =>
      'ReviewApiException: $message${body != null ? '\n$body' : ''}';
}

class RateLimitException extends ReviewApiException {
  final DateTime? resetAt;

  RateLimitException(super.message, {this.resetAt}) : super(code: 'RATE_LIMIT');

  Duration? get timeUntilReset {
    if (resetAt == null) return null;
    final diff = resetAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

// === Models ===

class HealthCheckResult {
  final bool isHealthy;
  final String? stockfishStatus;
  final int activeAnalyses;
  final int queueLength;
  final String? error;

  HealthCheckResult({
    required this.isHealthy,
    this.stockfishStatus,
    this.activeAnalyses = 0,
    this.queueLength = 0,
    this.error,
  });
}

/// Base class for review events from SSE stream
sealed class ReviewEvent {
  factory ReviewEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'progress' => ReviewProgressEvent.fromJson(json),
      'move' => ReviewMoveEvent.fromJson(json),
      'complete' => ReviewCompleteEvent.fromJson(json),
      'error' => ReviewErrorEvent.fromJson(json),
      _ => throw ArgumentError('Unknown event type: $type'),
    };
  }
}

class ReviewProgressEvent implements ReviewEvent {
  final int currentMove;
  final int totalMoves;
  final double percentage;

  ReviewProgressEvent({
    required this.currentMove,
    required this.totalMoves,
    required this.percentage,
  });

  factory ReviewProgressEvent.fromJson(Map<String, dynamic> json) {
    return ReviewProgressEvent(
      currentMove: json['currentMove'] as int? ?? 0,
      totalMoves: json['totalMoves'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReviewMoveEvent implements ReviewEvent {
  final int moveNumber;
  final String fen;
  final String move;
  final String san;
  final String markerType;
  final double centipawnLoss;
  final double evaluationBefore;
  final double evaluationAfter;
  final String bestMove;
  final String? bestMoveUci;

  ReviewMoveEvent({
    required this.moveNumber,
    required this.fen,
    required this.move,
    required this.san,
    required this.markerType,
    required this.centipawnLoss,
    required this.evaluationBefore,
    required this.evaluationAfter,
    required this.bestMove,
    this.bestMoveUci,
  });

  factory ReviewMoveEvent.fromJson(Map<String, dynamic> json) {
    return ReviewMoveEvent(
      moveNumber: json['moveNumber'] as int? ?? 0,
      fen: json['fen'] as String? ?? '',
      move: json['move'] as String? ?? '',
      san: json['san'] as String? ?? json['move'] as String? ?? '',
      markerType: json['markerType'] as String? ?? 'GOOD',
      centipawnLoss: (json['centipawnLoss'] as num?)?.toDouble() ?? 0,
      evaluationBefore: (json['evaluationBefore'] as num?)?.toDouble() ?? 0,
      evaluationAfter: (json['evaluationAfter'] as num?)?.toDouble() ?? 0,
      bestMove: json['bestMove'] as String? ?? '',
      bestMoveUci: json['bestMoveUci'] as String?,
    );
  }

  /// Get color based on move number (0-indexed: 0=white, 1=black, etc.)
  String get color => moveNumber % 2 == 0 ? 'white' : 'black';
}

class ReviewCompleteEvent implements ReviewEvent {
  final String reviewId;
  final Map<String, double> accuracy;
  final Map<String, int> summary;
  final int totalMoves;

  ReviewCompleteEvent({
    required this.reviewId,
    required this.accuracy,
    required this.summary,
    required this.totalMoves,
  });

  factory ReviewCompleteEvent.fromJson(Map<String, dynamic> json) {
    return ReviewCompleteEvent(
      reviewId: json['reviewId'] as String? ?? '',
      accuracy: Map<String, double>.from(
        (json['accuracy'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0)),
      ),
      summary: Map<String, int>.from(
        (json['summary'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
      ),
      totalMoves: json['totalMoves'] as int? ?? 0,
    );
  }
}

class ReviewErrorEvent implements ReviewEvent {
  final String message;
  final String? code;

  ReviewErrorEvent({required this.message, this.code});

  factory ReviewErrorEvent.fromJson(Map<String, dynamic> json) {
    return ReviewErrorEvent(
      message: json['message'] as String? ?? 'Unknown error',
      code: json['code'] as String?,
    );
  }
}

class PositionAnalysis {
  final double evaluation;
  final String bestMove;
  final List<TopMove> topMoves;
  final int? depth;

  PositionAnalysis({
    required this.evaluation,
    required this.bestMove,
    required this.topMoves,
    this.depth,
  });

  factory PositionAnalysis.fromJson(Map<String, dynamic> json) {
    return PositionAnalysis(
      evaluation: (json['evaluation'] as num?)?.toDouble() ?? 0,
      bestMove: json['bestMove'] as String? ?? '',
      topMoves: (json['topMoves'] as List? ?? [])
          .map((m) => TopMove.fromJson(m as Map<String, dynamic>))
          .toList(),
      depth: json['depth'] as int?,
    );
  }
}

class TopMove {
  final String uci;
  final int centipawns;

  TopMove({required this.uci, required this.centipawns});

  factory TopMove.fromJson(Map<String, dynamic> json) {
    return TopMove(
      uci: json['uci'] as String? ?? '',
      centipawns: json['cp'] as int? ?? 0,
    );
  }
}

class PuzzleExtractionResult {
  final List<ExtractedPuzzle> puzzles;
  final int totalExtracted;
  final PuzzleBreakdown breakdown;

  PuzzleExtractionResult({
    required this.puzzles,
    required this.totalExtracted,
    required this.breakdown,
  });

  factory PuzzleExtractionResult.fromJson(Map<String, dynamic> json) {
    return PuzzleExtractionResult(
      puzzles: (json['puzzles'] as List? ?? [])
          .map((p) => ExtractedPuzzle.fromJson(p as Map<String, dynamic>))
          .toList(),
      totalExtracted: json['totalExtracted'] as int? ?? 0,
      breakdown: PuzzleBreakdown.fromJson(
          json['breakdown'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ExtractedPuzzle {
  final String fen;
  final String playedMove;
  final String bestMove;
  final List<String> solution;
  final int rating;
  final List<String> themes;
  final String type;
  final int moveNumber;
  final double evaluationSwing;
  final int materialGain;

  ExtractedPuzzle({
    required this.fen,
    required this.playedMove,
    required this.bestMove,
    required this.solution,
    required this.rating,
    required this.themes,
    required this.type,
    required this.moveNumber,
    required this.evaluationSwing,
    required this.materialGain,
  });

  factory ExtractedPuzzle.fromJson(Map<String, dynamic> json) {
    return ExtractedPuzzle(
      fen: json['fen'] as String? ?? '',
      playedMove: json['playedMove'] as String? ?? '',
      bestMove: json['bestMove'] as String? ?? '',
      solution: List<String>.from(json['solution'] as List? ?? []),
      rating: json['rating'] as int? ?? 1200,
      themes: List<String>.from(json['themes'] as List? ?? []),
      type: json['type'] as String? ?? 'mistake',
      moveNumber: json['moveNumber'] as int? ?? 0,
      evaluationSwing: (json['evaluationSwing'] as num?)?.toDouble() ?? 0,
      materialGain: json['materialGain'] as int? ?? 0,
    );
  }
}

class PuzzleBreakdown {
  final int mistakes;
  final int missedTactics;
  final int positivePuzzles;

  PuzzleBreakdown({
    required this.mistakes,
    required this.missedTactics,
    required this.positivePuzzles,
  });

  factory PuzzleBreakdown.fromJson(Map<String, dynamic> json) {
    return PuzzleBreakdown(
      mistakes: json['mistakes'] as int? ?? 0,
      missedTactics: json['missedTactics'] as int? ?? 0,
      positivePuzzles: json['positivePuzzles'] as int? ?? 0,
    );
  }
}

class PuzzleSolution {
  final String fen;
  final String bestMove;
  final List<String> solution;
  final List<SolutionMove> solutionSequence;

  PuzzleSolution({
    required this.fen,
    required this.bestMove,
    required this.solution,
    required this.solutionSequence,
  });

  factory PuzzleSolution.fromJson(Map<String, dynamic> json) {
    return PuzzleSolution(
      fen: json['fen'] as String? ?? '',
      bestMove: json['bestMove'] as String? ?? '',
      solution: List<String>.from(json['solution'] as List? ?? []),
      solutionSequence: (json['solutionSequence'] as List? ?? [])
          .map((s) => SolutionMove.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SolutionMove {
  final String move;
  final bool isUserMove;
  final String? fen;

  SolutionMove({
    required this.move,
    required this.isUserMove,
    this.fen,
  });

  factory SolutionMove.fromJson(Map<String, dynamic> json) {
    return SolutionMove(
      move: json['move'] as String? ?? '',
      isUserMove: json['isUserMove'] as bool? ?? true,
      fen: json['fen'] as String?,
    );
  }
}
