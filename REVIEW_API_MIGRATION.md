# Migration Guide: חיבור לשרת Review API

## סטטוס: הושלם ✅

מסמך זה מפרט את השינויים שבוצעו בפרויקט `chess_mastery_flutter` כדי לעבוד מול שרת ה-Review API החדש.

### שינויים שבוצעו:

1. ✅ נוספו משתני סביבה ל-`.env`
2. ✅ נוצר `ReviewApiService` חדש
3. ✅ עודכן `GameReviewProvider` להשתמש ב-API (עם fallback מקומי)
4. ✅ עודכן `GamePuzzlesProvider` עם method חדש `extractPuzzlesFromServer`

---

## כתובות ה-API

| סביבה | כתובת |
|-------|-------|
| Production | `https://chessshare-review-api-production.up.railway.app` |
| Local | `http://192.168.1.232:3001` |

**Base Path:** `/api/v1`

---

## Endpoints זמינים בשרת

### 1. Game Review (ניתוח משחק)

**POST** `/api/v1/review`

```dart
// Request
{
  "pgn": "1. e4 e5 2. Nf3 ...",
  "playerColor": "white" | "black",
  "gameId": "optional-uuid",
  "platform": "lichess" | "chesscom",
  "options": {
    "depth": 18  // 6-24
  }
}

// Response: SSE Stream
// Event types: progress, move, complete, error
```

### 2. Position Analysis (ניתוח פוזיציה בודדת)

**POST** `/api/v1/review/position`

```dart
// Request
{
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
  "depth": 18
}

// Response
{
  "evaluation": 0.3,
  "bestMove": "e7e5",
  "topMoves": [{"uci": "e7e5", "cp": 30}],
  "depth": 18
}
```

### 3. Puzzle Extraction (חילוץ פאזלים)

**POST** `/api/v1/puzzles/extract`

```dart
// Request
{
  "pgn": "1. e4 e5 ...",
  "playerColor": "white" | "black",
  "reviewId": "optional-existing-review-id",
  "gameRating": 1500,
  "openingName": "Sicilian Defense"
}

// Response
{
  "puzzles": [
    {
      "fen": "...",
      "playedMove": "e2e4",
      "bestMove": "d2d4",
      "solution": ["d2d4", "e7e5", "d4e5"],
      "rating": 1400,
      "themes": ["fork", "winning_material"],
      "type": "mistake" | "missed_tactic" | "brilliant",
      "moveNumber": 15,
      "evaluationSwing": 150,
      "materialGain": 3
    }
  ],
  "totalExtracted": 5,
  "breakdown": {
    "mistakes": 3,
    "missedTactics": 1,
    "positivePuzzles": 1
  }
}
```

### 4. Puzzle Solution Generation

**POST** `/api/v1/puzzles/solution`

```dart
// Request
{
  "fen": "...",
  "bestMove": "d2d4",
  "isPositivePuzzle": false
}

// Response
{
  "fen": "...",
  "bestMove": "d2d4",
  "solution": ["d2d4", "e7e5", "d4e5"],
  "solutionSequence": [
    {"move": "d2d4", "isUserMove": true, "fen": "..."},
    {"move": "e7e5", "isUserMove": false, "fen": "..."}
  ]
}
```

---

## שינויים נדרשים בקוד

### 1. הוספת משתני סביבה (`.env`)

```env
# הוסף לקובץ .env
REVIEW_API_URL=https://chessshare-review-api-production.up.railway.app
REVIEW_API_URL_LOCAL=http://192.168.1.232:3001
```

### 2. יצירת Review API Service חדש

צור קובץ: `lib/core/api/review_api_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewApiService {
  static String get baseUrl {
    // Use local URL in debug mode, production otherwise
    const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) {
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
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Start game review with SSE streaming
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

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw ReviewApiException(
        'Failed to start review: ${response.statusCode}',
        body,
      );
    }

    // Parse SSE stream
    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (chunk.startsWith('data: ')) {
        final data = chunk.substring(6);
        if (data.isNotEmpty) {
          try {
            final json = jsonDecode(data);
            yield ReviewEvent.fromJson(json);
          } catch (e) {
            // Skip malformed events
          }
        }
      }
    }
  }

  /// Analyze single position
  static Future<PositionAnalysis> analyzePosition({
    required String fen,
    int? depth,
  }) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/review/position'),
      headers: headers,
      body: jsonEncode({
        'fen': fen,
        if (depth != null) 'depth': depth,
      }),
    );

    if (response.statusCode != 200) {
      throw ReviewApiException(
        'Position analysis failed: ${response.statusCode}',
        response.body,
      );
    }

    return PositionAnalysis.fromJson(jsonDecode(response.body));
  }

  /// Extract puzzles from game
  static Future<PuzzleExtractionResult> extractPuzzles({
    required String pgn,
    required String playerColor,
    String? reviewId,
    int? gameRating,
    String? openingName,
  }) async {
    final headers = await _getHeaders();

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

    if (response.statusCode != 200) {
      throw ReviewApiException(
        'Puzzle extraction failed: ${response.statusCode}',
        response.body,
      );
    }

    return PuzzleExtractionResult.fromJson(jsonDecode(response.body));
  }

  /// Generate puzzle solution
  static Future<PuzzleSolution> generateSolution({
    required String fen,
    required String bestMove,
    bool isPositivePuzzle = false,
  }) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/puzzles/solution'),
      headers: headers,
      body: jsonEncode({
        'fen': fen,
        'bestMove': bestMove,
        'isPositivePuzzle': isPositivePuzzle,
      }),
    );

    if (response.statusCode != 200) {
      throw ReviewApiException(
        'Solution generation failed: ${response.statusCode}',
        response.body,
      );
    }

    return PuzzleSolution.fromJson(jsonDecode(response.body));
  }
}

// === Models ===

class ReviewApiException implements Exception {
  final String message;
  final String? body;

  ReviewApiException(this.message, [this.body]);

  @override
  String toString() => 'ReviewApiException: $message${body != null ? '\n$body' : ''}';
}

sealed class ReviewEvent {
  factory ReviewEvent.fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'progress' => ReviewProgressEvent.fromJson(json),
      'move' => ReviewMoveEvent.fromJson(json),
      'complete' => ReviewCompleteEvent.fromJson(json),
      'error' => ReviewErrorEvent.fromJson(json),
      _ => throw ArgumentError('Unknown event type: ${json['type']}'),
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
      currentMove: json['currentMove'],
      totalMoves: json['totalMoves'],
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class ReviewMoveEvent implements ReviewEvent {
  final int moveNumber;
  final String fen;
  final String move;
  final String markerType;
  final double centipawnLoss;
  final double evaluationBefore;
  final double evaluationAfter;
  final String bestMove;

  ReviewMoveEvent({
    required this.moveNumber,
    required this.fen,
    required this.move,
    required this.markerType,
    required this.centipawnLoss,
    required this.evaluationBefore,
    required this.evaluationAfter,
    required this.bestMove,
  });

  factory ReviewMoveEvent.fromJson(Map<String, dynamic> json) {
    return ReviewMoveEvent(
      moveNumber: json['moveNumber'],
      fen: json['fen'],
      move: json['move'],
      markerType: json['markerType'],
      centipawnLoss: (json['centipawnLoss'] as num).toDouble(),
      evaluationBefore: (json['evaluationBefore'] as num).toDouble(),
      evaluationAfter: (json['evaluationAfter'] as num).toDouble(),
      bestMove: json['bestMove'],
    );
  }
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
      reviewId: json['reviewId'],
      accuracy: Map<String, double>.from(
        (json['accuracy'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      summary: Map<String, int>.from(json['summary']),
      totalMoves: json['totalMoves'],
    );
  }
}

class ReviewErrorEvent implements ReviewEvent {
  final String message;
  final String? code;

  ReviewErrorEvent({required this.message, this.code});

  factory ReviewErrorEvent.fromJson(Map<String, dynamic> json) {
    return ReviewErrorEvent(
      message: json['message'],
      code: json['code'],
    );
  }
}

class PositionAnalysis {
  final double evaluation;
  final String bestMove;
  final List<Map<String, dynamic>> topMoves;
  final int? depth;

  PositionAnalysis({
    required this.evaluation,
    required this.bestMove,
    required this.topMoves,
    this.depth,
  });

  factory PositionAnalysis.fromJson(Map<String, dynamic> json) {
    return PositionAnalysis(
      evaluation: (json['evaluation'] as num).toDouble(),
      bestMove: json['bestMove'],
      topMoves: List<Map<String, dynamic>>.from(json['topMoves']),
      depth: json['depth'],
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
      puzzles: (json['puzzles'] as List)
          .map((p) => ExtractedPuzzle.fromJson(p))
          .toList(),
      totalExtracted: json['totalExtracted'],
      breakdown: PuzzleBreakdown.fromJson(json['breakdown']),
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
      fen: json['fen'],
      playedMove: json['playedMove'],
      bestMove: json['bestMove'],
      solution: List<String>.from(json['solution']),
      rating: json['rating'],
      themes: List<String>.from(json['themes']),
      type: json['type'],
      moveNumber: json['moveNumber'],
      evaluationSwing: (json['evaluationSwing'] as num).toDouble(),
      materialGain: json['materialGain'],
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
      mistakes: json['mistakes'],
      missedTactics: json['missedTactics'],
      positivePuzzles: json['positivePuzzles'],
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
      fen: json['fen'],
      bestMove: json['bestMove'],
      solution: List<String>.from(json['solution']),
      solutionSequence: (json['solutionSequence'] as List)
          .map((s) => SolutionMove.fromJson(s))
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
      move: json['move'],
      isUserMove: json['isUserMove'],
      fen: json['fen'],
    );
  }
}
```

---

### 3. שינויים ב-GameReviewProvider

קובץ: `lib/features/games/providers/game_review_provider.dart`

**שינויים מרכזיים:**
- במקום לקרוא ל-`GameAnalysisService.analyzeGame()` (ניתוח מקומי)
- לקרוא ל-`ReviewApiService.reviewGame()` (שרת)

```dart
// לפני (ניתוח מקומי):
final moves = await GameAnalysisService.analyzeGame(
  pgn: game.pgn,
  playerColor: playerColor,
  onProgress: (current, total) {
    state = state.copyWith(
      status: GameReviewStatus.analyzing,
      progress: current / total,
    );
  },
);

// אחרי (שרת API):
final events = ReviewApiService.reviewGame(
  pgn: game.pgn,
  playerColor: playerColor.name,
  platform: game.platform?.toLowerCase(),
  gameId: game.gameId,
);

List<AnalyzedMove> moves = [];

await for (final event in events) {
  switch (event) {
    case ReviewProgressEvent():
      state = state.copyWith(
        status: GameReviewStatus.analyzing,
        progress: event.percentage / 100,
      );
    case ReviewMoveEvent():
      moves.add(_convertToAnalyzedMove(event));
    case ReviewCompleteEvent():
      // Use accuracy from server
      final accuracy = GameAccuracy(
        white: event.accuracy['white']!,
        black: event.accuracy['black']!,
      );
      // Save review...
    case ReviewErrorEvent():
      throw Exception(event.message);
  }
}
```

---

### 4. המרת MarkerType

מיפוי בין ה-API לבין הקיים באפליקציה:

```dart
MoveClassification _convertMarkerType(String serverMarkerType) {
  return switch (serverMarkerType) {
    'BOOK' => MoveClassification.book,
    'BRILLIANT' => MoveClassification.brilliant,
    'GREAT' => MoveClassification.great,
    'BEST' => MoveClassification.best,
    'GOOD' => MoveClassification.good,
    'INACCURACY' => MoveClassification.inaccuracy,
    'MISTAKE' => MoveClassification.mistake,
    'MISS' => MoveClassification.miss,
    'BLUNDER' => MoveClassification.blunder,
    _ => MoveClassification.good,
  };
}
```

---

### 5. שינויים ב-Puzzle Generation

קובץ: `lib/features/games/providers/game_puzzles_provider.dart`

```dart
// לפני (יצירה מקומית):
final puzzles = await _generatePuzzlesFromGame(game, moves);

// אחרי (שרת API):
final result = await ReviewApiService.extractPuzzles(
  pgn: game.pgn,
  playerColor: playerColor.name,
  gameRating: userRating,
  openingName: game.opening,
);

final puzzles = result.puzzles.map((p) => Puzzle(
  fen: p.fen,
  solutionUci: p.solution,
  rating: p.rating,
  themes: p.themes,
  // ... המרה לפורמט המקומי
)).toList();
```

---

## קוד למחיקה / ביטול

### קבצים שאפשר למחוק או להשבית:

1. **`lib/features/games/services/game_analysis_service.dart`**
   - הניתוח עכשיו נעשה בשרת
   - אפשר להשאיר כ-fallback לאופליין אם רוצים

2. **חלקים ב-Stockfish initialization ב-`main.dart`**
   - אם לא צריכים יותר Stockfish מקומי לניתוח משחקים
   - **הערה:** אולי עדיין צריך לפאזל solving (בדיקת מהלכים)

### פונקציות שאפשר לפשט:

1. **`GamePuzzlesNotifier._generatePuzzlesFromGame()`**
   - כל הלוגיקה של יצירת פאזלים עוברת לשרת
   - להחליף בקריאה ל-`ReviewApiService.extractPuzzles()`

2. **`GameAnalysisService.analyzeGame()`**
   - להחליף בקריאה ל-`ReviewApiService.reviewGame()`

---

## טיפול ב-Rate Limiting

השרת מחזיר headers עם מידע על rate limit:

```dart
// בתגובת השרת:
// X-RateLimit-Limit: 3
// X-RateLimit-Remaining: 2
// X-RateLimit-Reset: 2024-01-16T00:00:00.000Z

// בקוד Dart:
class RateLimitInfo {
  final int limit;
  final int remaining;
  final DateTime resetAt;

  bool get isExceeded => remaining <= 0;
}
```

הצג למשתמש כמה ניתוחים נשארו לו היום.

---

## טיפול בשגיאות

```dart
try {
  await for (final event in ReviewApiService.reviewGame(...)) {
    // ...
  }
} on ReviewApiException catch (e) {
  if (e.message.contains('429')) {
    // Rate limit exceeded
    showRateLimitDialog(context);
  } else if (e.message.contains('401')) {
    // Auth error - refresh token
    await SupabaseService.refreshSession();
  } else {
    // General error
    showErrorSnackbar(context, e.message);
  }
}
```

---

## Health Check (אופציונלי)

```dart
/// Check if API is available
static Future<bool> isApiHealthy() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/health'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'healthy';
    }
    return false;
  } catch (e) {
    return false;
  }
}
```

---

## סיכום משימות

| # | משימה | סטטוס |
|---|-------|-------|
| 1 | הוסף משתני סביבה ל-`.env` | ✅ הושלם |
| 2 | צור `ReviewApiService` | ✅ הושלם |
| 3 | עדכן `GameReviewProvider` לשימוש ב-API | ✅ הושלם |
| 4 | עדכן `GamePuzzlesProvider` לשימוש ב-API | ✅ הושלם |
| 5 | הוסף UI ל-rate limit | ⏳ עתידי |
| 6 | הוסף health check | ✅ הושלם (בתוך ReviewApiService) |
| 7 | שקול fallback מקומי (אופליין) | ✅ הושלם (ב-GameReviewProvider) |

---

## הערות נוספות

1. **אימות**: ה-API משתמש באותו JWT של Supabase - לא צריך שינוי בהתחברות
2. **SSE**: צריך לטפל ב-stream של אירועים - לא תגובת JSON רגילה
3. **מבנה פאזלים**: המבנה מהשרת קצת שונה - צריך המרה
4. **Rate Limit**: משתמשים חינמיים מוגבלים ל-3 ניתוחים ביום

---

## דוגמה לשימוש מלא

```dart
// בתוך Provider או ב-UI
Future<void> analyzeGame(ChessGame game) async {
  // 1. Check API health (optional)
  if (!await ReviewApiService.isApiHealthy()) {
    // Fallback to local analysis or show error
    return;
  }

  // 2. Start analysis stream
  final stream = ReviewApiService.reviewGame(
    pgn: game.pgn,
    playerColor: playerColor.name,
    platform: game.platform,
  );

  // 3. Handle events
  await for (final event in stream) {
    switch (event) {
      case ReviewProgressEvent():
        updateProgress(event.percentage);
      case ReviewMoveEvent():
        addAnalyzedMove(event);
      case ReviewCompleteEvent():
        finalizeReview(event);
      case ReviewErrorEvent():
        handleError(event);
    }
  }

  // 4. Extract puzzles
  final puzzles = await ReviewApiService.extractPuzzles(
    pgn: game.pgn,
    playerColor: playerColor.name,
    reviewId: reviewId,
  );

  savePuzzles(puzzles);
}
```
