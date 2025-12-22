# ChessShare Flutter App - Bug Report

> **Status: ALL BUGS FIXED** (Updated: 2025-12-21)

## Bug #1: Flash Screen Shows Login Before Data Loads

### Problem
When the app starts, there's a brief flash where the login screen is visible before the user's data is loaded. This happens because the auth state transitions from `isLoading: true` to `isLoading: false` before the profile is fully loaded from Supabase.

### Current Flow (Problematic)
```
1. App starts → router initialLocation = '/splash'
2. AuthNotifier._init() starts with isLoading: true
3. Tries to load local profile AND Supabase profile
4. If Supabase check is slow, sets isLoading: false before profile loads
5. Router sees isLoading: false + no profile → redirects to '/login'
6. Profile loads from Supabase → redirects to '/games'
7. User sees: Splash → Login (flash) → Games
```

### Location of Bug
- `lib/features/auth/providers/auth_provider.dart` - lines 66-134
- The `_init()` method sets `isLoading: false` in line 129 when no Supabase session, before profile may have loaded

### Solution
Keep `isLoading: true` until ALL profile loading attempts complete:
```dart
// Don't set isLoading: false until we've finished ALL checks
// Move the isLoading: false to after _loadProfile completes
```

---

## Bug #2: Analysis NOT Saved to Server (CRITICAL)

### Problem
When a game is analyzed, the results are ONLY saved to the local SQLite database. They are NEVER sent to Supabase. This means:
- Analyzed games don't sync across devices
- The server never receives the analysis
- Other users can't see shared analysis

### Current Flow (Problematic)
```
game_analysis_service.dart:
  Line 154: LocalDatabase.saveGameReview()     ← LOCAL ONLY
  Line 349: LocalDatabase.saveAnalyzedMoves()  ← LOCAL ONLY
  Line 354: LocalDatabase.completeGameReview() ← LOCAL ONLY
  Line 641: LocalDatabase.savePersonalMistake() ← LOCAL ONLY
```

### What's Missing
The following server API calls are NEVER made after analysis:

1. **`save_game_review`** - Save game review metadata
   - Must be called with: externalGameId, platform, pgn, playerColor, gameResult, speed, timeControl, playedAt, opponentUsername, ratings, accuracy scores, move counts

2. **`save_game_review_moves`** - Save move evaluations
   - Must be called with: gameReviewId, array of moves with FEN, SAN, evaluation, marker_type, best_move

3. **`save_personal_mistakes`** - Save generated puzzles
   - Must be called with: gameReviewId, array of mistakes with FEN, solution_sequence (array of moves)

### Location of Bug
- `lib/features/games/services/game_analysis_service.dart` - entire file only saves to LocalDatabase
- `lib/core/repositories/games_repository.dart` - has the functions but they're NEVER CALLED

### Web Project Reference (Correct Implementation)
From `chessy-linker/src/lib/server/game-review.ts`:
```typescript
// 1. Save game review
const reviewId = await saveGameReview(supabase, reviewData);

// 2. Save move evaluations
await saveGameReviewMoves(supabase, reviewId, moves);

// 3. Save personal mistakes as puzzles
await savePersonalMistakes(supabase, reviewId, mistakes);
```

### Solution
After `LocalDatabase.completeGameReview()` in `game_analysis_service.dart`, add:

```dart
// Save to server (if authenticated)
final user = SupabaseService.currentUser;
if (user != null) {
  // 1. Save game review to server
  final serverReviewId = await GamesRepository.saveGameReview(
    externalGameId: game.externalId,
    platform: game.platform.name,
    pgn: game.pgn,
    playerColor: game.playerColor,
    gameResult: game.result.name,
    speed: game.speed.name,
    timeControl: game.timeControl,
    playedAt: game.playedAt,
    opponentUsername: game.opponentUsername,
    opponentRating: game.opponentRating,
    playerRating: game.playerRating,
    openingEco: game.openingEco,
    openingName: game.openingName,
    accuracyWhite: whiteSummary.accuracy,
    accuracyBlack: blackSummary.accuracy,
    movesTotal: analyzedMoves.length,
    movesBook: analyzedMoves.where((m) => m.classification == MoveClassification.book).length,
    movesBrilliant: analyzedMoves.where((m) => m.classification == MoveClassification.brilliant).length,
    movesGreat: analyzedMoves.where((m) => m.classification == MoveClassification.great).length,
    movesBest: analyzedMoves.where((m) => m.classification == MoveClassification.best).length,
    movesGood: analyzedMoves.where((m) => m.classification == MoveClassification.good).length,
    movesInaccuracy: analyzedMoves.where((m) => m.classification == MoveClassification.inaccuracy).length,
    movesMistake: analyzedMoves.where((m) => m.classification == MoveClassification.mistake).length,
    movesBlunder: analyzedMoves.where((m) => m.classification == MoveClassification.blunder).length,
  );

  if (serverReviewId != null) {
    // 2. Save move evaluations
    await GamesRepository.saveGameReviewMoves(
      gameReviewId: serverReviewId,
      moves: analyzedMoves.map((m) => {
        'move_index': m.moveNumber - 1,
        'fen': m.fen,
        'san': m.san,
        'evaluation_before': m.evalBefore,
        'evaluation_after': m.evalAfter,
        'marker_type': m.classification.name,
        'best_move': m.bestMove,
        'centipawn_loss': m.centipawnLoss,
      }).toList(),
    );

    // 3. Save puzzles (personal mistakes) - need to add this RPC function
    // await GamesRepository.savePersonalMistakes(...);
  }
}
```

---

## Bug #3: API Endpoints ARE Defined But Not Used Correctly

### Problem
The correct API endpoints exist in `games_repository.dart` but the data flow is incomplete:
- `getUserGameReviews()` IS called correctly in `games_provider.dart:288`
- `getGameReview()` and `getGameReviewMoves()` ARE called in `game_review_provider.dart:169-183`
- BUT `saveGameReview()` and `saveGameReviewMoves()` are NEVER called

### Correct API Functions (Already Exist)
| Function | File | Status |
|----------|------|--------|
| `get_user_game_reviews` | games_repository.dart:38 | ✅ Used in games_provider.dart |
| `get_linked_chess_accounts` | auth_provider.dart:251 | ✅ Used correctly |
| `get_game_review` | games_repository.dart:53 | ✅ Used in game_review_provider.dart |
| `get_game_review_moves` | games_repository.dart:79 | ✅ Used in game_review_provider.dart |
| `save_game_review` | games_repository.dart:93 | ❌ NEVER CALLED |
| `save_game_review_moves` | games_repository.dart:154 | ❌ NEVER CALLED |
| `save_personal_mistakes` | N/A | ❌ NOT IMPLEMENTED |

### Missing: `save_personal_mistakes` RPC Function
Need to add to `games_repository.dart`:
```dart
static Future<bool> savePersonalMistakes({
  required String gameReviewId,
  required List<Map<String, dynamic>> mistakes,
}) async {
  final result = await BaseRepository.executeRpc<bool>(
    functionName: 'save_personal_mistakes',
    params: {
      'p_game_review_id': gameReviewId,
      'p_mistakes': mistakes.map((m) => {
        'fen': m['fen'],
        'solution_sequence': [m['solution_uci']], // Array of UCI moves
        'classification': m['classification'],
        'theme': m['theme'],
      }).toList(),
    },
    parser: (_) => true,
    defaultValue: false,
  );
  return result.success;
}
```

---

## Summary of Required Changes

### File: `lib/features/games/services/game_analysis_service.dart`

After analysis completes (around line 360), add server sync:
1. Call `GamesRepository.saveGameReview()` with all game metadata
2. Call `GamesRepository.saveGameReviewMoves()` with move evaluations
3. Call `GamesRepository.savePersonalMistakes()` with generated puzzles

### File: `lib/core/repositories/games_repository.dart`

Add missing function:
- `savePersonalMistakes()` - to save puzzles to server

### File: `lib/features/auth/providers/auth_provider.dart`

Fix isLoading timing:
- Keep `isLoading: true` until ALL profile checks complete
- Only set `isLoading: false` after Supabase profile load attempt finishes

---

## Priority

| Bug | Priority | Impact |
|-----|----------|--------|
| #2 Analysis not saved | CRITICAL | Data loss - no sync |
| #3 API not called | CRITICAL | Part of #2 |
| #1 Flash screen | Medium | UX issue only |
