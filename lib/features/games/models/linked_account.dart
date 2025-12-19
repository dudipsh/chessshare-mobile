import 'chess_game.dart';

/// A linked chess platform account (Chess.com or Lichess)
class LinkedAccount {
  final String id;
  final String userId;
  final GamePlatform platform;
  final String username;
  final bool isVerified;
  final int? rating; // Current rating if available
  final DateTime? lastSynced;
  final DateTime createdAt;

  LinkedAccount({
    required this.id,
    required this.userId,
    required this.platform,
    required this.username,
    this.isVerified = false,
    this.rating,
    this.lastSynced,
    required this.createdAt,
  });

  /// Platform display name
  String get platformName {
    switch (platform) {
      case GamePlatform.chesscom:
        return 'Chess.com';
      case GamePlatform.lichess:
        return 'Lichess';
    }
  }

  /// Platform icon asset or URL
  String get platformIconUrl {
    switch (platform) {
      case GamePlatform.chesscom:
        return 'https://www.chess.com/favicon.ico';
      case GamePlatform.lichess:
        return 'https://lichess.org/favicon.ico';
    }
  }

  /// Profile URL on the platform
  String get profileUrl {
    switch (platform) {
      case GamePlatform.chesscom:
        return 'https://www.chess.com/member/$username';
      case GamePlatform.lichess:
        return 'https://lichess.org/@/$username';
    }
  }

  factory LinkedAccount.fromJson(Map<String, dynamic> json) {
    return LinkedAccount(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      platform: GamePlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => GamePlatform.chesscom,
      ),
      username: json['username'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      rating: json['rating'] as int?,
      lastSynced: json['last_synced'] != null
          ? DateTime.parse(json['last_synced'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'platform': platform.name,
      'username': username,
      'is_verified': isVerified,
      'rating': rating,
      'last_synced': lastSynced?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  LinkedAccount copyWith({
    String? id,
    String? userId,
    GamePlatform? platform,
    String? username,
    bool? isVerified,
    int? rating,
    DateTime? lastSynced,
    DateTime? createdAt,
  }) {
    return LinkedAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      username: username ?? this.username,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      lastSynced: lastSynced ?? this.lastSynced,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
