import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/models/user_profile.dart';
import '../../features/games/models/linked_account.dart';
import '../../features/games/models/chess_game.dart';

class LocalDatabase {
  static Database? _database;
  static const String _databaseName = 'chessshare.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String userProfileTable = 'user_profile';
  static const String gamesTable = 'games';
  static const String puzzlesTable = 'puzzles';
  static const String linkedAccountsTable = 'linked_accounts';
  static const String gameReviewsTable = 'game_reviews';
  static const String gameReviewMovesTable = 'game_review_moves';
  static const String personalMistakesTable = 'personal_mistakes';

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

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
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
}
