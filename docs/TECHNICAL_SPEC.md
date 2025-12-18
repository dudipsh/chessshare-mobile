# Chess Mastery - Flutter App Technical Specification

## Executive Summary

Chess Mastery is a premium native Flutter application focused on game analysis and study training. The app connects to the existing Chess Share Supabase backend, providing a superior native experience for serious chess players.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Chess Mastery Flutter App                   │
├─────────────────────────────────────────────────────────────────┤
│  Presentation Layer                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │   Screens   │ │   Widgets   │ │  Animations │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
├─────────────────────────────────────────────────────────────────┤
│  State Management (Riverpod 2.x)                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │  Providers  │ │  Notifiers  │ │    State    │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
├─────────────────────────────────────────────────────────────────┤
│  Domain Layer                                                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │   Models    │ │ Use Cases   │ │ Repositories│               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │  Supabase   │ │   SQLite    │ │  Stockfish  │               │
│  │   Remote    │ │   Local     │ │    FFI      │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
└─────────────────────────────────────────────────────────────────┘
                         │
                         │ HTTPS / REST / Realtime
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Supabase Backend (Shared)                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │    Auth     │ │  Database   │ │Edge Functions│               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── app/
│   ├── app.dart                       # MaterialApp configuration
│   ├── router.dart                    # GoRouter configuration
│   └── theme/
│       ├── app_theme.dart             # Premium dark/light themes
│       ├── colors.dart                # Color palette
│       └── typography.dart            # Custom fonts
│
├── core/
│   ├── chess/
│   │   ├── board/
│   │   │   ├── chess_board.dart       # Main board widget
│   │   │   ├── board_painter.dart     # Custom painting
│   │   │   ├── piece_widget.dart      # Animated pieces
│   │   │   └── markers/
│   │   │       ├── move_marker.dart   # Move indicators
│   │   │       ├── arrow_marker.dart  # Arrow overlays
│   │   │       └── highlight.dart     # Square highlights
│   │   ├── logic/
│   │   │   ├── chess_engine.dart      # Chess rules (chess.dart)
│   │   │   ├── pgn_parser.dart        # PGN parsing
│   │   │   └── fen_utils.dart         # FEN utilities
│   │   ├── stockfish/
│   │   │   ├── stockfish_service.dart # FFI bindings
│   │   │   ├── analysis_result.dart   # Evaluation data
│   │   │   └── uci_protocol.dart      # UCI commands
│   │   └── sounds/
│   │       ├── sound_service.dart     # Sound playback
│   │       └── haptic_service.dart    # Haptic feedback
│   │
│   ├── api/
│   │   ├── supabase_client.dart       # Supabase initialization
│   │   ├── auth_service.dart          # Authentication
│   │   ├── chess_com_api.dart         # Chess.com API
│   │   └── lichess_api.dart           # Lichess API
│   │
│   ├── database/
│   │   ├── local_database.dart        # SQLite wrapper
│   │   ├── tables/
│   │   │   ├── cached_games.dart
│   │   │   ├── cached_boards.dart
│   │   │   ├── offline_analysis.dart
│   │   │   └── sync_queue.dart
│   │   └── sync_service.dart          # Online/offline sync
│   │
│   └── utils/
│       ├── extensions.dart
│       ├── logger.dart
│       └── date_utils.dart
│
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── onboarding_screen.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── widgets/
│   │       └── social_login_buttons.dart
│   │
│   ├── games/
│   │   ├── screens/
│   │   │   ├── games_list_screen.dart
│   │   │   ├── game_detail_screen.dart
│   │   │   └── import_screen.dart
│   │   ├── providers/
│   │   │   ├── games_provider.dart
│   │   │   └── import_provider.dart
│   │   ├── models/
│   │   │   ├── game.dart
│   │   │   └── game_filter.dart
│   │   └── widgets/
│   │       ├── game_card.dart
│   │       ├── games_filter_sheet.dart
│   │       └── import_progress.dart
│   │
│   ├── analysis/
│   │   ├── screens/
│   │   │   ├── analysis_screen.dart
│   │   │   └── move_explorer_screen.dart
│   │   ├── providers/
│   │   │   ├── analysis_provider.dart
│   │   │   └── stockfish_provider.dart
│   │   ├── models/
│   │   │   ├── move_evaluation.dart
│   │   │   └── analysis_result.dart
│   │   └── widgets/
│   │       ├── eval_bar.dart
│   │       ├── move_list.dart
│   │       ├── accuracy_chart.dart
│   │       └── move_quality_badge.dart
│   │
│   ├── study/
│   │   ├── screens/
│   │   │   ├── boards_list_screen.dart
│   │   │   ├── study_screen.dart
│   │   │   └── practice_screen.dart
│   │   ├── providers/
│   │   │   ├── boards_provider.dart
│   │   │   └── study_progress_provider.dart
│   │   ├── models/
│   │   │   ├── board.dart
│   │   │   └── variation.dart
│   │   └── widgets/
│   │       ├── board_card.dart
│   │       ├── variation_list.dart
│   │       └── progress_indicator.dart
│   │
│   ├── puzzles/
│   │   ├── screens/
│   │   │   ├── puzzles_screen.dart
│   │   │   └── puzzle_practice_screen.dart
│   │   ├── providers/
│   │   │   └── puzzles_provider.dart
│   │   └── widgets/
│   │       ├── puzzle_card.dart
│   │       └── streak_indicator.dart
│   │
│   ├── insights/
│   │   ├── screens/
│   │   │   └── insights_screen.dart
│   │   ├── providers/
│   │   │   └── insights_provider.dart
│   │   └── widgets/
│   │       ├── rating_chart.dart
│   │       ├── opening_breakdown.dart
│   │       ├── accuracy_trends.dart
│   │       └── mistake_patterns.dart
│   │
│   ├── profile/
│   │   ├── screens/
│   │   │   ├── profile_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── providers/
│   │       └── profile_provider.dart
│   │
│   └── subscription/
│       ├── screens/
│       │   └── subscription_screen.dart
│       ├── providers/
│       │   └── subscription_provider.dart
│       └── widgets/
│           └── plan_card.dart
│
└── shared/
    ├── widgets/
    │   ├── app_bar.dart
    │   ├── bottom_nav.dart
    │   ├── loading_indicator.dart
    │   ├── error_view.dart
    │   └── empty_state.dart
    └── animations/
        ├── fade_transition.dart
        ├── slide_transition.dart
        └── scale_transition.dart
```

---

## Supabase API Reference

### Authentication

```dart
// Sign in with Google
final response = await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'com.chessmastery.app://login-callback',
);

// Sign in with Apple
final response = await supabase.auth.signInWithOAuth(
  OAuthProvider.apple,
  redirectTo: 'com.chessmastery.app://login-callback',
);

// Get current session
final session = supabase.auth.currentSession;
final user = supabase.auth.currentUser;

// Sign out
await supabase.auth.signOut();
```

### Profile Management

```dart
// Get user profile
final response = await supabase.rpc('get_my_profile');
// Returns: { id, full_name, avatar_url, email, chess_com_username,
//            subscription_type, subscription_end_date, ... }

// Update profile
await supabase.from('profiles').update({
  'full_name': name,
  'chess_com_username': username,
}).eq('id', userId);

// Get public profiles (for showing opponent info)
final response = await supabase.rpc('get_public_profiles', {
  'user_ids': ['uuid1', 'uuid2']
});
```

### Game Reviews

```dart
// Save game review
final response = await supabase.rpc('save_game_review', {
  'p_external_game_id': 'abc123',
  'p_platform': 'chesscom', // or 'lichess'
  'p_pgn': '1. e4 e5 2. Nf3...',
  'p_player_color': 'white',
  'p_game_result': 'win', // 'loss', 'draw'
  'p_speed': 'blitz', // 'bullet', 'rapid', 'classical'
  'p_time_control': '3+0',
  'p_played_at': '2024-01-15T10:30:00Z',
  'p_opponent_username': 'opponent123',
  'p_opponent_rating': 1500,
  'p_player_rating': 1550,
  'p_opening_eco': 'C50',
  'p_opening_name': 'Italian Game',
  'p_accuracy_white': 92.5,
  'p_accuracy_black': 88.3,
  'p_moves_total': 45,
  'p_moves_book': 5,
  'p_moves_brilliant': 1,
  'p_moves_great': 3,
  'p_moves_best': 15,
  'p_moves_good': 12,
  'p_moves_inaccuracy': 5,
  'p_moves_mistake': 3,
  'p_moves_blunder': 1,
});
// Returns: game_review_id (UUID)

// Get existing game review
final response = await supabase.rpc('get_game_review', {
  'p_platform': 'chesscom',
  'p_external_game_id': 'abc123',
});
// Returns: Full game review data if exists

// Get user game review stats
final response = await supabase.rpc('get_user_game_review_stats', {
  'p_user_id': userId,
});
// Returns: { total_games, wins, losses, draws, avg_accuracy, ... }

// Save move evaluations for a game
await supabase.rpc('save_game_review_moves', {
  'p_game_review_id': gameReviewId,
  'p_moves': [
    {
      'move_index': 0,
      'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'san': 'e4',
      'marker_type': 'book',
      'centipawn_loss': 0,
      'evaluation_before': 0.2,
      'evaluation_after': 0.3,
      'best_move': 'e4',
    },
    // ... more moves
  ],
});

// Get move evaluations for a game
final response = await supabase.rpc('get_game_review_moves', {
  'p_game_review_id': gameReviewId,
});
```

### Personal Mistakes & Puzzles

```dart
// Save mistakes from a game for practice
await supabase.rpc('save_personal_mistakes', {
  'p_game_review_id': gameReviewId,
  'p_mistakes': [
    {
      'fen': 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
      'played_move': 'Nc3',
      'best_move': 'Ng5',
      'evaluation_loss': 150,
      'marker_type': 'mistake',
      'move_number': 4,
      'player_color': 'white',
      'opening_name': 'Italian Game',
      'game_rating': 1550,
      'puzzle_rating': 1750,
      'is_positive_puzzle': false,
      'solution_sequence': [
        {'move': 'g1f3', 'isUserMove': true},
        {'move': 'b8c6', 'isUserMove': false},
        // ...
      ],
    },
  ],
});

// Get all user puzzles for practice
final response = await supabase.rpc('get_all_user_puzzles', {
  'p_user_id': userId,
});

// Get mistakes for specific game
final response = await supabase.rpc('get_mistakes_for_game', {
  'p_game_review_id': gameReviewId,
});

// Get difficult mistakes (for focused practice)
final response = await supabase.rpc('get_difficult_mistakes', {
  'p_user_id': userId,
  'p_limit': 20,
});

// Update mistake after practice attempt
await supabase.rpc('update_mistake_after_practice', {
  'p_mistake_id': mistakeId,
  'p_solved': true,
  'p_time_spent_seconds': 45,
});

// Get mistakes for insights analysis
final response = await supabase.rpc('get_mistakes_for_insights');
```

### Study Boards

```dart
// Get board with progress
final response = await supabase.rpc('get_board_with_progress', {
  'p_board_id': boardId,
  'p_user_id': userId,
});
// Returns: Full board data with variations and user progress

// Get public boards paginated
final response = await supabase.rpc('get_public_boards_paginated', {
  'page_limit': 20,
  'last_views_count': lastBoard?.viewsCount,
  'last_board_id': lastBoard?.id,
});

// Get my boards with progress
final response = await supabase.rpc('get_my_boards_with_progress', {
  'p_user_id': userId,
});

// Get user progress boards (only boards with some progress)
final response = await supabase.rpc('get_user_progress_boards', {
  'p_user_id': userId,
});

// Update study progress
await supabase.rpc('update_user_progress', {
  'p_user_id': userId,
  'p_board_id': boardId,
  'p_variation_id': variationId,
  'p_node_id': null,
  'p_fen': currentFen,
  'p_moves_completed': moveNumber,
});

// Mark board as completed
await supabase.rpc('mark_board_completed', {
  'p_board_id': boardId,
  'p_user_id': userId,
});

// Reset board progress
await supabase.rpc('reset_board_progress', {
  'p_board_id': boardId,
});

// Get user progress stats
final response = await supabase.rpc('get_user_progress_stats', {
  'p_user_id': userId,
});
// Returns: { total_boards_started, total_boards_completed, ... }
```

### Board Variations

```dart
// Get variation review (analysis data)
final response = await supabase.rpc('get_variation_review', {
  'p_variation_id': variationId,
});

// Save variation review
await supabase.rpc('save_variation_review', {
  'p_variation_id': variationId,
  'p_review_data': {
    'accuracy': 94.5,
    'moves_evaluated': [...],
  },
});
```

### Libraries (Collections)

```dart
// Get user libraries
final response = await supabase.rpc('get_user_libraries', {
  'p_user_id': userId,
});

// Get public libraries
final response = await supabase.rpc('get_public_libraries', {
  'p_limit': 20,
  'p_offset': 0,
});

// Get library boards
final response = await supabase.rpc('get_library_boards', {
  'p_library_id': libraryId,
});

// Create library
final response = await supabase.rpc('create_library', {
  'p_name': 'My Openings',
  'p_description': 'Collection of opening studies',
  'p_is_public': false,
});

// Add boards to library
await supabase.rpc('add_boards_to_library', {
  'p_library_id': libraryId,
  'p_board_ids': ['board1', 'board2'],
});

// Remove boards from library
await supabase.rpc('remove_boards_from_library', {
  'p_library_id': libraryId,
  'p_board_ids': ['board1'],
});

// Toggle library like
await supabase.rpc('toggle_library_like', {
  'p_library_id': libraryId,
});

// Get library stats
final response = await supabase.rpc('get_library_stats', {
  'p_library_id': libraryId,
});
```

### Leaderboards & XP

```dart
// Get weekly XP leaderboard
final response = await supabase.rpc('get_top_users_by_weekly_xp', {
  'limit_count': 50,
});

// Get all-time XP leaderboard
final response = await supabase.rpc('get_top_users_by_total_xp', {
  'limit_count': 50,
});

// Add XP event (via Edge Function)
await supabase.functions.invoke('add-xp-event', {
  body: {
    'event_source': 'game_analyzed',
    'xp_value': 10,
    'related_id': gameId,
  },
});

// Check daily login streak
final response = await supabase.rpc('check_and_award_daily_login', {
  'p_user_id': userId,
});

// Get login streak
final response = await supabase.rpc('get_user_login_streak', {
  'p_user_id': userId,
});
```

### Search

```dart
// Search boards and users
final response = await supabase.rpc('search_boards_and_users', {
  'search_query': 'sicilian defense',
  'sort_by': 'relevance', // 'views', 'likes', 'date'
  'limit_count': 20,
  'offset_count': 0,
});

// Search boards by opening
final response = await supabase.rpc('search_boards_by_opening', {
  'opening_name': 'Sicilian',
});

// Get search suggestions
final response = await supabase.rpc('get_search_suggestions', {
  'partial_term': 'sic',
  'limit_count': 5,
});
```

### Notifications

```dart
// Get user notifications
final response = await supabase.rpc('get_user_notifications', {
  'p_user_id': userId,
  'p_limit': 20,
});

// Mark notification as read
await supabase.from('notifications').update({
  'is_read': true,
}).eq('id', notificationId);

// Subscribe to real-time notifications
final channel = supabase
  .channel('notifications')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'notifications',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    ),
    callback: (payload) {
      // Handle new notification
    },
  )
  .subscribe();
```

### Feature Flags

```dart
// Get user features
final response = await supabase.rpc('get_user_features', {
  'target_user_id': userId,
});
// Returns: [{ feature: 'game_analysis', enabled: true }, ...]

// Get my features (current user)
final response = await supabase.rpc('get_my_features');
```

### Subscriptions

```dart
// Check subscription status
final response = await supabase.rpc('is_subscription_active', {
  'user_id': userId,
});

// Get subscription from profile
final profile = await supabase.rpc('get_my_profile');
// profile.subscription_type: 'FREE' | 'BASIC' | 'PRO'
// profile.subscription_end_date: ISO date string
```

---

## External APIs

### Chess.com API

```dart
class ChessComApi {
  static const baseUrl = 'https://api.chess.com/pub';

  // Get user profile
  Future<ChessComProfile> getProfile(String username) async {
    final response = await http.get(
      Uri.parse('$baseUrl/player/$username'),
    );
    return ChessComProfile.fromJson(jsonDecode(response.body));
  }

  // Get user stats (ratings)
  Future<ChessComStats> getStats(String username) async {
    final response = await http.get(
      Uri.parse('$baseUrl/player/$username/stats'),
    );
    return ChessComStats.fromJson(jsonDecode(response.body));
  }

  // Get monthly game archives list
  Future<List<String>> getArchives(String username) async {
    final response = await http.get(
      Uri.parse('$baseUrl/player/$username/games/archives'),
    );
    return List<String>.from(jsonDecode(response.body)['archives']);
  }

  // Get games from specific month
  Future<List<ChessComGame>> getMonthGames(String archiveUrl) async {
    final response = await http.get(Uri.parse(archiveUrl));
    final games = jsonDecode(response.body)['games'] as List;
    return games.map((g) => ChessComGame.fromJson(g)).toList();
  }
}
```

### Lichess API

```dart
class LichessApi {
  static const baseUrl = 'https://lichess.org/api';

  // Get user profile
  Future<LichessProfile> getProfile(String username) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/$username'),
      headers: {'Accept': 'application/json'},
    );
    return LichessProfile.fromJson(jsonDecode(response.body));
  }

  // Get user games (NDJSON stream)
  Stream<LichessGame> getGames(String username, {
    int max = 100,
    bool analysed = true,
  }) async* {
    final response = await http.get(
      Uri.parse('$baseUrl/games/user/$username?max=$max&analysed=$analysed'),
      headers: {'Accept': 'application/x-ndjson'},
    );

    final lines = response.body.split('\n');
    for (final line in lines) {
      if (line.isNotEmpty) {
        yield LichessGame.fromJson(jsonDecode(line));
      }
    }
  }

  // Get game by ID
  Future<LichessGame> getGame(String gameId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/game/$gameId'),
      headers: {'Accept': 'application/json'},
    );
    return LichessGame.fromJson(jsonDecode(response.body));
  }
}
```

---

## Local Database Schema (SQLite)

```sql
-- Cached games for offline viewing
CREATE TABLE cached_games (
  id TEXT PRIMARY KEY,
  external_game_id TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'chesscom' | 'lichess'
  pgn TEXT NOT NULL,
  player_color TEXT NOT NULL,
  game_result TEXT NOT NULL,
  opponent_username TEXT,
  opponent_rating INTEGER,
  player_rating INTEGER,
  played_at TEXT,
  opening_name TEXT,
  time_control TEXT,
  speed TEXT,
  -- Analysis data
  accuracy_white REAL,
  accuracy_black REAL,
  move_evaluations TEXT, -- JSON array
  analysis_completed INTEGER DEFAULT 0,
  -- Metadata
  cached_at TEXT NOT NULL,
  last_accessed TEXT NOT NULL,
  UNIQUE(platform, external_game_id)
);

CREATE INDEX idx_cached_games_platform ON cached_games(platform);
CREATE INDEX idx_cached_games_played_at ON cached_games(played_at);
CREATE INDEX idx_cached_games_last_accessed ON cached_games(last_accessed);

-- Cached study boards
CREATE TABLE cached_boards (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  owner_id TEXT NOT NULL,
  owner_name TEXT,
  cover_image_url TEXT,
  starting_fen TEXT,
  variations TEXT NOT NULL, -- JSON array
  -- User progress
  progress_percent REAL DEFAULT 0,
  current_variation_id TEXT,
  current_move_index INTEGER DEFAULT 0,
  -- Metadata
  cached_at TEXT NOT NULL,
  last_accessed TEXT NOT NULL,
  is_pinned INTEGER DEFAULT 0
);

CREATE INDEX idx_cached_boards_last_accessed ON cached_boards(last_accessed);
CREATE INDEX idx_cached_boards_pinned ON cached_boards(is_pinned);

-- Offline personal puzzles
CREATE TABLE cached_puzzles (
  id TEXT PRIMARY KEY,
  fen TEXT NOT NULL,
  solution_sequence TEXT NOT NULL, -- JSON array
  marker_type TEXT NOT NULL,
  puzzle_rating INTEGER,
  opening_name TEXT,
  -- Practice data
  attempts INTEGER DEFAULT 0,
  solved INTEGER DEFAULT 0,
  last_practiced TEXT,
  next_review TEXT, -- SM-2 spaced repetition
  ease_factor REAL DEFAULT 2.5,
  interval_days INTEGER DEFAULT 1,
  -- Source
  game_review_id TEXT,
  -- Metadata
  cached_at TEXT NOT NULL
);

CREATE INDEX idx_cached_puzzles_next_review ON cached_puzzles(next_review);
CREATE INDEX idx_cached_puzzles_marker_type ON cached_puzzles(marker_type);

-- Sync queue for offline changes
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL, -- 'create' | 'update' | 'delete'
  data TEXT NOT NULL, -- JSON
  created_at TEXT NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
);

CREATE INDEX idx_sync_queue_created ON sync_queue(created_at);

-- User preferences
CREATE TABLE preferences (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Analysis cache (for expensive Stockfish calculations)
CREATE TABLE analysis_cache (
  fen TEXT PRIMARY KEY,
  depth INTEGER NOT NULL,
  evaluation REAL NOT NULL,
  best_move TEXT NOT NULL,
  pv_line TEXT, -- JSON array of moves
  created_at TEXT NOT NULL
);

CREATE INDEX idx_analysis_cache_created ON analysis_cache(created_at);
```

---

## Stockfish Integration

### FFI Setup

```dart
// pubspec.yaml
dependencies:
  stockfish: ^2.1.0  # Stockfish FFI binding

// lib/core/chess/stockfish/stockfish_service.dart
import 'package:stockfish/stockfish.dart';

class StockfishService {
  static Stockfish? _stockfish;
  static bool _isReady = false;

  static Future<void> initialize() async {
    _stockfish = Stockfish();
    await _stockfish!.ready;
    _isReady = true;

    // Set options for mobile
    _stockfish!.stdin = 'setoption name Threads value 2';
    _stockfish!.stdin = 'setoption name Hash value 64';
  }

  static Future<AnalysisResult> analyze(
    String fen, {
    int depth = 20,
    int multiPv = 1,
  }) async {
    if (!_isReady) await initialize();

    final completer = Completer<AnalysisResult>();

    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'setoption name MultiPV value $multiPv';
    _stockfish!.stdin = 'go depth $depth';

    String? bestMove;
    double? evaluation;
    List<String> pvLine = [];

    _stockfish!.stdout.listen((line) {
      if (line.contains('bestmove')) {
        bestMove = _parseBestMove(line);
        completer.complete(AnalysisResult(
          bestMove: bestMove!,
          evaluation: evaluation ?? 0,
          pvLine: pvLine,
          depth: depth,
        ));
      } else if (line.contains('info depth')) {
        final parsed = _parseInfo(line);
        evaluation = parsed.evaluation;
        pvLine = parsed.pv;
      }
    });

    return completer.future.timeout(
      Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Analysis timeout'),
    );
  }

  static void dispose() {
    _stockfish?.dispose();
    _stockfish = null;
    _isReady = false;
  }
}
```

---

## Premium Features Configuration

```dart
// lib/core/config/subscription_config.dart

enum SubscriptionTier {
  free,
  basic,
  pro,
}

class SubscriptionConfig {
  static const Map<SubscriptionTier, SubscriptionLimits> limits = {
    SubscriptionTier.free: SubscriptionLimits(
      dailyGameAnalyses: 2,
      stockfishDepth: 15,
      offlineGamesLimit: 10,
      offlineBoardsLimit: 5,
      adsEnabled: true,
      cloudSync: false,
      advancedInsights: false,
    ),
    SubscriptionTier.basic: SubscriptionLimits(
      dailyGameAnalyses: -1, // unlimited
      stockfishDepth: 22,
      offlineGamesLimit: 100,
      offlineBoardsLimit: 50,
      adsEnabled: false,
      cloudSync: true,
      advancedInsights: true,
    ),
    SubscriptionTier.pro: SubscriptionLimits(
      dailyGameAnalyses: -1,
      stockfishDepth: 30,
      stockfishMultiPv: 3, // Show top 3 moves
      offlineGamesLimit: -1, // unlimited
      offlineBoardsLimit: -1,
      adsEnabled: false,
      cloudSync: true,
      advancedInsights: true,
      prioritySupport: true,
    ),
  };
}

class SubscriptionLimits {
  final int dailyGameAnalyses;
  final int stockfishDepth;
  final int stockfishMultiPv; // Number of best lines to show
  final int offlineGamesLimit;
  final int offlineBoardsLimit;
  final bool adsEnabled;
  final bool cloudSync;
  final bool advancedInsights;
  final bool prioritySupport;

  const SubscriptionLimits({
    required this.dailyGameAnalyses,
    required this.stockfishDepth,
    this.stockfishMultiPv = 1,
    required this.offlineGamesLimit,
    required this.offlineBoardsLimit,
    required this.adsEnabled,
    required this.cloudSync,
    required this.advancedInsights,
    this.prioritySupport = false,
  });
}
```

---

## Dependencies

```yaml
# pubspec.yaml
name: chess_mastery
description: Premium Chess Analysis & Training App
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # Navigation
  go_router: ^13.0.0

  # Supabase
  supabase_flutter: ^2.3.0

  # Local Database
  sqflite: ^2.3.2
  path_provider: ^2.1.2

  # Chess
  chess: ^0.8.4
  stockfish: ^2.1.0

  # UI & Animations
  flutter_animate: ^4.5.0
  lottie: ^3.0.0
  shimmer: ^3.0.0
  cached_network_image: ^3.3.1

  # Charts
  fl_chart: ^0.66.2

  # Audio & Haptics
  audioplayers: ^5.2.1
  vibration: ^1.8.4

  # Utilities
  intl: ^0.19.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  collection: ^1.18.0

  # Network
  http: ^1.2.0
  connectivity_plus: ^5.0.2

  # Storage
  shared_preferences: ^2.2.2

  # In-App Purchase
  in_app_purchase: ^3.1.13

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.8
  riverpod_generator: ^2.3.9
  freezed: ^2.4.6
  json_serializable: ^6.7.1

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/sounds/
    - assets/fonts/
    - assets/animations/

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

---

## Sound Assets

Required sound files in `assets/sounds/`:

```
assets/sounds/
├── move.mp3           # Regular piece move
├── capture.mp3        # Piece capture
├── check.mp3          # Check
├── checkmate.mp3      # Checkmate
├── castle.mp3         # Castling
├── illegal.mp3        # Illegal move attempt
├── game_start.mp3     # Game/analysis start
├── game_end.mp3       # Game/analysis end
├── correct.mp3        # Correct puzzle move
├── incorrect.mp3      # Incorrect puzzle move
├── level_up.mp3       # Level up celebration
└── achievement.mp3    # Achievement unlocked
```

---

## Next Steps

1. Initialize Flutter project with this structure
2. Set up Supabase client with existing credentials
3. Implement core chess board widget with animations
4. Build authentication flow
5. Implement game import from Chess.com/Lichess
6. Add Stockfish analysis
7. Build study mode with progress tracking
8. Implement offline mode with SQLite
9. Add subscription management
10. Polish animations and premium feel
