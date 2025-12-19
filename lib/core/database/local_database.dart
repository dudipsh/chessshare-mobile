import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/auth/models/user_profile.dart';

class LocalDatabase {
  static Database? _database;
  static const String _databaseName = 'chessshare.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String userProfileTable = 'user_profile';
  static const String gamesTable = 'games';
  static const String puzzlesTable = 'puzzles';

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
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here
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
  }
}
