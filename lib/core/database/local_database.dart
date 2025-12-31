import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/models/user_profile.dart';
import '../../features/games/models/linked_account.dart';
import '../../features/games/models/chess_game.dart';
import '../../features/study/models/study_board.dart';

class LocalDatabase {
  static Database? _database;
  static const String _databaseName = 'chessshare.db';
  static const int _databaseVersion = 7;

  // Table names
  static const String userProfileTable = 'user_profile';
  static const String gamesTable = 'games';
  static const String puzzlesTable = 'puzzles';
  static const String linkedAccountsTable = 'linked_accounts';
  static const String gameReviewsTable = 'game_reviews';
  static const String gameReviewMovesTable = 'game_review_moves';
  static const String personalMistakesTable = 'personal_mistakes';
  static const String studyBoardsTable = 'study_boards';
  static const String studyVariationsTable = 'study_variations';
  static const String boardViewsTable = 'board_views';
  static const String boardLikesCacheTable = 'board_likes_cache';
  static const String gamePuzzlesTable = 'game_puzzles';

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // User profile table
    await db.execute('''
      CREATE TABLE $userProfileTable (
        id TEXT PRIMARY KEY,
        email TEXT,
        full_name TEXT,
        avatar_url TEXT,
        chess_com_username TEXT,
        lichess_username TEXT,
        subscription_type TEXT DEFAULT 'FREE',
        subscription_end_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Games table for offline storage
    await db.execute('''
      CREATE TABLE $gamesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        pgn TEXT NOT NULL,
        platform TEXT,
        result TEXT,
        player_color TEXT,
        opponent_username TEXT,
        played_at TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Puzzles table
    await db.execute('''
      CREATE TABLE $puzzlesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        fen TEXT NOT NULL,
        solution TEXT NOT NULL,
        solution_san TEXT,
        rating INTEGER,
        theme TEXT,
        description TEXT,
        completed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Version 2 tables
    await _createV2Tables(db);

    // Version 4 tables (study boards)
    await _createV4Tables(db);

    // Version 6 tables (board views, likes cache)
    await _createV6Tables(db);

    // Version 7 tables (game puzzles with multi-move solutions)
    await _createV7Tables(db);
  }

  static Future<void> _createV2Tables(Database db) async {
    // Linked chess accounts (Chess.com, Lichess)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $linkedAccountsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        username TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        rating INTEGER,
        last_synced TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(user_id, platform)
      )
    ''');

    // Game reviews (analyzed games)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $gameReviewsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        game_id TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        progress REAL DEFAULT 0,
        white_summary TEXT,
        black_summary TEXT,
        depth INTEGER DEFAULT 18,
        analyzed_at TEXT,
        created_at TEXT NOT NULL,
        error_message TEXT,
        UNIQUE(user_id, game_id)
      )
    ''');

    // Analyzed moves for game reviews
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $gameReviewMovesTable (
        id TEXT PRIMARY KEY,
        game_review_id TEXT NOT NULL,
        move_number INTEGER NOT NULL,
        color TEXT NOT NULL,
        fen TEXT NOT NULL,
        san TEXT NOT NULL,
        uci TEXT NOT NULL,
        classification TEXT,
        eval_before INTEGER,
        eval_after INTEGER,
        mate_before INTEGER,
        mate_after INTEGER,
        best_move TEXT,
        best_move_uci TEXT,
        centipawn_loss INTEGER DEFAULT 0,
        comment TEXT,
        has_puzzle INTEGER DEFAULT 0,
        FOREIGN KEY (game_review_id) REFERENCES $gameReviewsTable(id) ON DELETE CASCADE
      )
    ''');

    // Personal mistakes (puzzles from own games)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $personalMistakesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        game_review_id TEXT,
        move_id TEXT,
        fen TEXT NOT NULL,
        solution_uci TEXT NOT NULL,
        solution_san TEXT NOT NULL,
        classification TEXT NOT NULL,
        theme TEXT,
        rating INTEGER DEFAULT 1500,
        times_practiced INTEGER DEFAULT 0,
        times_correct INTEGER DEFAULT 0,
        last_practiced TEXT,
        next_review TEXT,
        ease_factor REAL DEFAULT 2.5,
        interval_days INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (game_review_id) REFERENCES $gameReviewsTable(id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_linked_accounts_user ON $linkedAccountsTable(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_game_reviews_user ON $gameReviewsTable(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_game_reviews_game ON $gameReviewsTable(game_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_review_moves_review ON $gameReviewMovesTable(game_review_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_personal_mistakes_user ON $personalMistakesTable(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_personal_mistakes_next_review ON $personalMistakesTable(next_review)');
  }

  /// Helper to add column only if it doesn't exist
  static Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      // Check if column exists by querying table info
      final result = await db.rawQuery("PRAGMA table_info($table)");
      final columnExists = result.any((col) => col['name'] == column);

      if (!columnExists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
        debugPrint('Added column $column to $table');
      } else {
        debugPrint('Column $column already exists in $table');
      }
    } catch (e) {
      debugPrint('Error checking/adding column $column: $e');
    }
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      await _createV2Tables(db);
    }

    if (oldVersion < 3) {
      // Add is_positive column to puzzles table
      await _addColumnIfNotExists(db, puzzlesTable, 'is_positive', 'INTEGER DEFAULT 0');
    }

    if (oldVersion < 4) {
      await _createV4Tables(db);
    }

    if (oldVersion < 5) {
      // Ensure is_positive column exists (may have been missed in v3 migration)
      await _addColumnIfNotExists(db, puzzlesTable, 'is_positive', 'INTEGER DEFAULT 0');
    }

    if (oldVersion < 6) {
      await _createV6Tables(db);
    }

    if (oldVersion < 7) {
      await _createV7Tables(db);
    }
  }

  /// Create V4 tables (study boards)
  static Future<void> _createV4Tables(Database db) async {
    // Study boards table for local caching
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $studyBoardsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        owner_id TEXT NOT NULL,
        owner_name TEXT,
        owner_avatar_url TEXT,
        cover_image_url TEXT,
        is_public INTEGER DEFAULT 1,
        views_count INTEGER DEFAULT 0,
        likes_count INTEGER DEFAULT 0,
        user_liked INTEGER DEFAULT 0,
        starting_fen TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    // Study variations table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $studyVariationsTable (
        id TEXT PRIMARY KEY,
        board_id TEXT NOT NULL,
        name TEXT NOT NULL,
        pgn TEXT NOT NULL,
        starting_fen TEXT,
        player_color TEXT,
        position INTEGER DEFAULT 0,
        moves_completed INTEGER DEFAULT 0,
        total_moves INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        completion_percentage REAL DEFAULT 0,
        FOREIGN KEY (board_id) REFERENCES $studyBoardsTable(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_study_boards_owner ON $studyBoardsTable(owner_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_study_variations_board ON $studyVariationsTable(board_id)');
  }

  /// Create V6 tables (board views and likes cache for Study feature)
  static Future<void> _createV6Tables(Database db) async {
    // Track viewed boards locally (for History tab)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $boardViewsTable (
        board_id TEXT PRIMARY KEY,
        board_data TEXT NOT NULL,
        viewed_at INTEGER NOT NULL,
        view_count INTEGER DEFAULT 1
      )
    ''');

    // Cache liked boards (for Liked tab)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $boardLikesCacheTable (
        board_id TEXT PRIMARY KEY,
        board_data TEXT NOT NULL,
        liked_at INTEGER NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_board_views_viewed_at ON $boardViewsTable(viewed_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_board_likes_liked_at ON $boardLikesCacheTable(liked_at DESC)');

    debugPrint('Created V6 tables: board_views, board_likes_cache');
  }

  /// Create V7 tables (game puzzles with multi-move solutions)
  static Future<void> _createV7Tables(Database db) async {
    // Game puzzles table for multi-move puzzle sequences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $gamePuzzlesTable (
        id TEXT PRIMARY KEY,
        game_review_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        fen TEXT NOT NULL,
        player_color TEXT NOT NULL,
        solution_uci TEXT NOT NULL,
        solution_san TEXT NOT NULL,
        classification TEXT NOT NULL,
        theme TEXT,
        move_number INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (game_review_id) REFERENCES $gameReviewsTable(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_game_puzzles_review ON $gamePuzzlesTable(game_review_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_game_puzzles_user ON $gamePuzzlesTable(user_id)');

    debugPrint('Created V7 tables: game_puzzles');
  }

  // User Profile operations
  static Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      userProfileTable,
      {
        ...profile.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<UserProfile?> getUserProfile(String id) async {
    final db = await database;
    final results = await db.query(
      userProfileTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return UserProfile.fromJson(results.first);
  }

  static Future<UserProfile?> getCurrentUserProfile() async {
    final db = await database;
    final results = await db.query(
      userProfileTable,
      limit: 1,
      orderBy: 'updated_at DESC',
    );

    if (results.isEmpty) return null;
    return UserProfile.fromJson(results.first);
  }

  static Future<void> updateUserProfile(String id, Map<String, dynamic> updates) async {
    final db = await database;
    updates['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      userProfileTable,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteUserProfile(String id) async {
    final db = await database;
    await db.delete(
      userProfileTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete(userProfileTable);
    await db.delete(gamesTable);
    await db.delete(puzzlesTable);
    await db.delete(linkedAccountsTable);
    await db.delete(gameReviewsTable);
    await db.delete(gameReviewMovesTable);
    await db.delete(personalMistakesTable);
  }

  // ========== Linked Accounts ==========

  static Future<void> saveLinkedAccount(LinkedAccount account) async {
    final db = await database;
    await db.insert(
      linkedAccountsTable,
      {
        ...account.toJson(),
        'is_verified': account.isVerified ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<LinkedAccount>> getLinkedAccounts(String userId) async {
    final db = await database;
    final results = await db.query(
      linkedAccountsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return results.map((json) => LinkedAccount.fromJson({
      ...json,
      'is_verified': json['is_verified'] == 1,
    })).toList();
  }

  static Future<LinkedAccount?> getLinkedAccount(String userId, GamePlatform platform) async {
    final db = await database;
    final results = await db.query(
      linkedAccountsTable,
      where: 'user_id = ? AND platform = ?',
      whereArgs: [userId, platform.name],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return LinkedAccount.fromJson({
      ...results.first,
      'is_verified': results.first['is_verified'] == 1,
    });
  }

  static Future<void> deleteLinkedAccount(String id) async {
    final db = await database;
    await db.delete(
      linkedAccountsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateLinkedAccountSync(String id, DateTime lastSynced) async {
    final db = await database;
    await db.update(
      linkedAccountsTable,
      {'last_synced': lastSynced.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Game Reviews ==========

  static Future<void> saveGameReview(Map<String, dynamic> review) async {
    final db = await database;
    await db.insert(
      gameReviewsTable,
      review,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getGameReview(String id) async {
    final db = await database;
    final results = await db.query(
      gameReviewsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  static Future<Map<String, dynamic>?> getGameReviewByGameId(String userId, String gameId) async {
    final db = await database;
    final results = await db.query(
      gameReviewsTable,
      where: 'user_id = ? AND game_id = ?',
      whereArgs: [userId, gameId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  static Future<List<Map<String, dynamic>>> getGameReviews(String userId, {int limit = 50}) async {
    final db = await database;
    return await db.query(
      gameReviewsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  static Future<void> updateGameReviewProgress(String id, double progress, String status) async {
    final db = await database;
    await db.update(
      gameReviewsTable,
      {
        'progress': progress,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> completeGameReview(
    String id,
    String whiteSummaryJson,
    String blackSummaryJson,
  ) async {
    final db = await database;
    await db.update(
      gameReviewsTable,
      {
        'status': 'completed',
        'progress': 1.0,
        'white_summary': whiteSummaryJson,
        'black_summary': blackSummaryJson,
        'analyzed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete game review and its moves by game ID
  static Future<void> deleteGameReviewByGameId(String userId, String gameId) async {
    final db = await database;

    // First get the review to find its ID
    final review = await getGameReviewByGameId(userId, gameId);
    if (review != null) {
      final reviewId = review['id'] as String;

      // Delete the moves first
      await db.delete(
        gameReviewMovesTable,
        where: 'game_review_id = ?',
        whereArgs: [reviewId],
      );

      // Delete the review
      await db.delete(
        gameReviewsTable,
        where: 'id = ?',
        whereArgs: [reviewId],
      );
    }
  }

  // ========== Game Review Moves ==========

  static Future<void> saveAnalyzedMoves(List<Map<String, dynamic>> moves) async {
    final db = await database;
    final batch = db.batch();

    for (final move in moves) {
      batch.insert(
        gameReviewMovesTable,
        {
          ...move,
          'has_puzzle': move['has_puzzle'] == true ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getAnalyzedMoves(String gameReviewId) async {
    final db = await database;
    final results = await db.query(
      gameReviewMovesTable,
      where: 'game_review_id = ?',
      whereArgs: [gameReviewId],
      orderBy: 'move_number ASC',
    );

    return results.map((r) => {
      ...r,
      'has_puzzle': r['has_puzzle'] == 1,
    }).toList();
  }

  // ========== Personal Mistakes (Puzzles) ==========

  static Future<void> savePersonalMistake(Map<String, dynamic> mistake) async {
    final db = await database;
    await db.insert(
      personalMistakesTable,
      mistake,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getPersonalMistakes(
    String userId, {
    int limit = 50,
    bool dueForReview = false,
  }) async {
    final db = await database;

    String? where = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (dueForReview) {
      where += ' AND (next_review IS NULL OR next_review <= ?)';
      whereArgs.add(DateTime.now().toIso8601String());
    }

    return await db.query(
      personalMistakesTable,
      where: where,
      whereArgs: whereArgs,
      orderBy: dueForReview ? 'next_review ASC' : 'created_at DESC',
      limit: limit,
    );
  }

  static Future<void> updateMistakePractice(
    String id, {
    required bool wasCorrect,
    required double newEaseFactor,
    required int newInterval,
    required DateTime nextReview,
  }) async {
    final db = await database;
    final mistake = await db.query(
      personalMistakesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (mistake.isEmpty) return;

    final current = mistake.first;
    await db.update(
      personalMistakesTable,
      {
        'times_practiced': (current['times_practiced'] as int) + 1,
        'times_correct': wasCorrect
            ? (current['times_correct'] as int) + 1
            : current['times_correct'],
        'last_practiced': DateTime.now().toIso8601String(),
        'ease_factor': newEaseFactor,
        'interval_days': newInterval,
        'next_review': nextReview.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> getDueReviewCount(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $personalMistakesTable WHERE user_id = ? AND (next_review IS NULL OR next_review <= ?)',
      [userId, DateTime.now().toIso8601String()],
    );
    return result.first['count'] as int;
  }

  // ========== Puzzles Cache ==========

  /// Save puzzles to local cache
  static Future<void> savePuzzles(String userId, List<Map<String, dynamic>> puzzles) async {
    final db = await database;
    final batch = db.batch();

    for (final puzzle in puzzles) {
      batch.insert(
        puzzlesTable,
        {
          'id': puzzle['id'],
          'user_id': userId,
          'fen': puzzle['fen'],
          'solution': puzzle['solution'],
          'solution_san': puzzle['solution_san'],
          'rating': puzzle['rating'],
          'theme': puzzle['theme'],
          'description': puzzle['description'],
          'is_positive': puzzle['is_positive'] == true ? 1 : 0,
          'completed': puzzle['completed'] == true ? 1 : 0,
          'created_at': puzzle['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('Cached ${puzzles.length} puzzles locally');
  }

  /// Get cached puzzles for a user
  static Future<List<Map<String, dynamic>>> getPuzzles(String userId) async {
    final db = await database;
    final results = await db.query(
      puzzlesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return results.map((r) => {
      ...r,
      'is_positive': r['is_positive'] == 1,
      'completed': r['completed'] == 1,
    }).toList();
  }

  /// Clear puzzles cache for a user
  static Future<void> clearPuzzlesCache(String userId) async {
    final db = await database;
    await db.delete(
      puzzlesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Get timestamp of last puzzle cache update
  static Future<DateTime?> getPuzzlesCacheTime(String userId) async {
    final db = await database;
    final results = await db.query(
      puzzlesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    final createdAt = results.first['created_at'] as String?;
    return createdAt != null ? DateTime.tryParse(createdAt) : null;
  }

  // ========== Study Boards Cache ==========

  /// Save a study board with its variations to local cache
  static Future<void> saveStudyBoard(StudyBoard board) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Save the board
    await db.insert(
      studyBoardsTable,
      {
        'id': board.id,
        'title': board.title,
        'description': board.description,
        'owner_id': board.ownerId,
        'owner_name': board.ownerName,
        'owner_avatar_url': board.ownerAvatarUrl,
        'cover_image_url': board.coverImageUrl,
        'is_public': board.isPublic ? 1 : 0,
        'views_count': board.viewsCount,
        'likes_count': board.likesCount,
        'user_liked': board.userLiked ? 1 : 0,
        'starting_fen': board.startingFen,
        'created_at': board.createdAt.toIso8601String(),
        'updated_at': board.updatedAt.toIso8601String(),
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save variations
    for (final variation in board.variations) {
      await db.insert(
        studyVariationsTable,
        {
          'id': variation.id,
          'board_id': board.id,
          'name': variation.name,
          'pgn': variation.pgn,
          'starting_fen': variation.startingFen,
          'player_color': variation.playerColor,
          'position': variation.position,
          'moves_completed': variation.movesCompleted,
          'total_moves': variation.totalMoves,
          'is_completed': variation.isCompleted ? 1 : 0,
          'completion_percentage': variation.completionPercentage,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    debugPrint('Cached study board: ${board.title} with ${board.variations.length} variations');
  }

  /// Get a study board from local cache
  static Future<StudyBoard?> getStudyBoard(String boardId) async {
    final db = await database;

    final boardResults = await db.query(
      studyBoardsTable,
      where: 'id = ?',
      whereArgs: [boardId],
      limit: 1,
    );

    if (boardResults.isEmpty) return null;

    final boardRow = boardResults.first;

    // Get variations
    final variationResults = await db.query(
      studyVariationsTable,
      where: 'board_id = ?',
      whereArgs: [boardId],
      orderBy: 'position ASC',
    );

    final variations = variationResults.map((v) => StudyVariation(
      id: v['id'] as String,
      boardId: v['board_id'] as String,
      name: v['name'] as String,
      pgn: v['pgn'] as String,
      startingFen: v['starting_fen'] as String?,
      playerColor: v['player_color'] as String?,
      position: v['position'] as int? ?? 0,
      movesCompleted: v['moves_completed'] as int? ?? 0,
      totalMoves: v['total_moves'] as int? ?? 0,
      isCompleted: v['is_completed'] == 1,
      completionPercentage: (v['completion_percentage'] as num?)?.toDouble() ?? 0,
    )).toList();

    return StudyBoard(
      id: boardRow['id'] as String,
      title: boardRow['title'] as String,
      description: boardRow['description'] as String?,
      ownerId: boardRow['owner_id'] as String,
      ownerName: boardRow['owner_name'] as String?,
      ownerAvatarUrl: boardRow['owner_avatar_url'] as String?,
      coverImageUrl: boardRow['cover_image_url'] as String?,
      isPublic: boardRow['is_public'] == 1,
      viewsCount: boardRow['views_count'] as int? ?? 0,
      likesCount: boardRow['likes_count'] as int? ?? 0,
      userLiked: boardRow['user_liked'] == 1,
      startingFen: boardRow['starting_fen'] as String?,
      variations: variations,
      createdAt: DateTime.parse(boardRow['created_at'] as String),
      updatedAt: DateTime.parse(boardRow['updated_at'] as String),
    );
  }

  /// Get all cached study boards for a user (their own boards)
  static Future<List<StudyBoard>> getUserStudyBoards(String userId) async {
    final db = await database;

    final boardResults = await db.query(
      studyBoardsTable,
      where: 'owner_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );

    final boards = <StudyBoard>[];
    for (final row in boardResults) {
      final board = await getStudyBoard(row['id'] as String);
      if (board != null) boards.add(board);
    }

    return boards;
  }

  /// Get all cached public study boards
  static Future<List<StudyBoard>> getCachedPublicBoards() async {
    final db = await database;

    final boardResults = await db.query(
      studyBoardsTable,
      where: 'is_public = 1',
      orderBy: 'views_count DESC',
      limit: 50,
    );

    final boards = <StudyBoard>[];
    for (final row in boardResults) {
      final board = await getStudyBoard(row['id'] as String);
      if (board != null) boards.add(board);
    }

    return boards;
  }

  /// Delete a study board from cache
  static Future<void> deleteStudyBoard(String boardId) async {
    final db = await database;

    // Delete variations first (foreign key)
    await db.delete(
      studyVariationsTable,
      where: 'board_id = ?',
      whereArgs: [boardId],
    );

    // Delete board
    await db.delete(
      studyBoardsTable,
      where: 'id = ?',
      whereArgs: [boardId],
    );
  }

  /// Check if a study board is cached
  static Future<bool> isStudyBoardCached(String boardId) async {
    final db = await database;
    final results = await db.query(
      studyBoardsTable,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [boardId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Get cache timestamp for a study board
  static Future<DateTime?> getStudyBoardCacheTime(String boardId) async {
    final db = await database;
    final results = await db.query(
      studyBoardsTable,
      columns: ['cached_at'],
      where: 'id = ?',
      whereArgs: [boardId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final cachedAt = results.first['cached_at'] as String?;
    return cachedAt != null ? DateTime.tryParse(cachedAt) : null;
  }

  // ========== Board Views (History) ==========

  /// Record a board view (for History tab)
  static Future<void> recordBoardView(String boardId, String boardDataJson) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if already exists
    final existing = await db.query(
      boardViewsTable,
      where: 'board_id = ?',
      whereArgs: [boardId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update view count and timestamp
      final currentCount = existing.first['view_count'] as int? ?? 0;
      await db.update(
        boardViewsTable,
        {
          'viewed_at': now,
          'view_count': currentCount + 1,
          'board_data': boardDataJson,
        },
        where: 'board_id = ?',
        whereArgs: [boardId],
      );
    } else {
      // Insert new
      await db.insert(
        boardViewsTable,
        {
          'board_id': boardId,
          'board_data': boardDataJson,
          'viewed_at': now,
          'view_count': 1,
        },
      );
    }
  }

  /// Get viewed boards history (most recent first)
  static Future<List<Map<String, dynamic>>> getBoardViewHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      boardViewsTable,
      orderBy: 'viewed_at DESC',
      limit: limit,
    );
  }

  /// Clear board view history
  static Future<void> clearBoardViewHistory() async {
    final db = await database;
    await db.delete(boardViewsTable);
  }

  /// Delete a specific board from history
  static Future<void> deleteBoardFromHistory(String boardId) async {
    final db = await database;
    await db.delete(
      boardViewsTable,
      where: 'board_id = ?',
      whereArgs: [boardId],
    );
  }

  // ========== Board Likes Cache ==========

  /// Add a liked board to cache
  static Future<void> addLikedBoard(String boardId, String boardDataJson) async {
    final db = await database;
    await db.insert(
      boardLikesCacheTable,
      {
        'board_id': boardId,
        'board_data': boardDataJson,
        'liked_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove a liked board from cache
  static Future<void> removeLikedBoard(String boardId) async {
    final db = await database;
    await db.delete(
      boardLikesCacheTable,
      where: 'board_id = ?',
      whereArgs: [boardId],
    );
  }

  /// Get all liked boards from cache (most recent first)
  static Future<List<Map<String, dynamic>>> getLikedBoards({int limit = 50}) async {
    final db = await database;
    return await db.query(
      boardLikesCacheTable,
      orderBy: 'liked_at DESC',
      limit: limit,
    );
  }

  /// Check if a board is liked (in cache)
  static Future<bool> isBoardLiked(String boardId) async {
    final db = await database;
    final results = await db.query(
      boardLikesCacheTable,
      columns: ['board_id'],
      where: 'board_id = ?',
      whereArgs: [boardId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Sync liked boards from server (replace all)
  static Future<void> syncLikedBoards(List<Map<String, dynamic>> boards) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing
      await txn.delete(boardLikesCacheTable);
      // Insert all
      for (final board in boards) {
        await txn.insert(boardLikesCacheTable, board);
      }
    });
  }

  /// Clear all liked boards cache
  static Future<void> clearLikedBoardsCache() async {
    final db = await database;
    await db.delete(boardLikesCacheTable);
  }

  // ========== Game Puzzles (Multi-Move) ==========

  /// Save game puzzles for a game review
  static Future<void> saveGamePuzzles(String userId, List<Map<String, dynamic>> puzzles) async {
    final db = await database;
    final batch = db.batch();

    for (final puzzle in puzzles) {
      batch.insert(
        gamePuzzlesTable,
        {
          'id': puzzle['id'],
          'game_review_id': puzzle['game_review_id'],
          'user_id': userId,
          'fen': puzzle['fen'],
          'player_color': puzzle['player_color'],
          'solution_uci': puzzle['solution_uci'], // JSON array as string
          'solution_san': puzzle['solution_san'], // JSON array as string
          'classification': puzzle['classification'],
          'theme': puzzle['theme'],
          'move_number': puzzle['move_number'],
          'created_at': puzzle['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('Saved ${puzzles.length} game puzzles locally');
  }

  /// Get game puzzles for a specific game review
  static Future<List<Map<String, dynamic>>> getGamePuzzles(String gameReviewId) async {
    final db = await database;
    return await db.query(
      gamePuzzlesTable,
      where: 'game_review_id = ?',
      whereArgs: [gameReviewId],
      orderBy: 'move_number ASC',
    );
  }

  /// Get all game puzzles for a user
  static Future<List<Map<String, dynamic>>> getUserGamePuzzles(String userId, {int limit = 50}) async {
    final db = await database;
    return await db.query(
      gamePuzzlesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Check if puzzles exist for a game review
  static Future<bool> hasGamePuzzles(String gameReviewId) async {
    final db = await database;
    final results = await db.query(
      gamePuzzlesTable,
      columns: ['id'],
      where: 'game_review_id = ?',
      whereArgs: [gameReviewId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Delete game puzzles for a specific game review
  static Future<void> deleteGamePuzzles(String gameReviewId) async {
    final db = await database;
    await db.delete(
      gamePuzzlesTable,
      where: 'game_review_id = ?',
      whereArgs: [gameReviewId],
    );
  }
}
