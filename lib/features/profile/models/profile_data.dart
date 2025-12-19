// Profile data models for the profile feature

class ProfileData {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? bio;
  final String? badgeType;
  final int followersCount;
  final int boardsCount;
  final int librariesCount;
  final int totalViews;
  final String? chessComUsername;
  final String? lichessUsername;
  final DateTime createdAt;

  ProfileData({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.coverImageUrl,
    this.bio,
    this.badgeType,
    this.followersCount = 0,
    this.boardsCount = 0,
    this.librariesCount = 0,
    this.totalViews = 0,
    this.chessComUsername,
    this.lichessUsername,
    required this.createdAt,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      bio: json['bio'] as String?,
      badgeType: json['badge_type'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      boardsCount: json['boards_count'] as int? ?? 0,
      librariesCount: json['libraries_count'] as int? ?? 0,
      totalViews: json['total_views'] as int? ?? 0,
      chessComUsername: json['chess_com_username'] as String?,
      lichessUsername: json['lichess_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'cover_image_url': coverImageUrl,
      'bio': bio,
      'badge_type': badgeType,
      'followers_count': followersCount,
      'boards_count': boardsCount,
      'libraries_count': librariesCount,
      'total_views': totalViews,
      'chess_com_username': chessComUsername,
      'lichess_username': lichessUsername,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ProfileBioLink {
  final String id;
  final String userId;
  final String linkType;
  final String url;
  final String? label;
  final int sortOrder;

  ProfileBioLink({
    required this.id,
    required this.userId,
    required this.linkType,
    required this.url,
    this.label,
    this.sortOrder = 0,
  });

  factory ProfileBioLink.fromJson(Map<String, dynamic> json) {
    return ProfileBioLink(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      linkType: json['link_type'] as String,
      url: json['url'] as String,
      label: json['label'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  String get displayName {
    if (label != null && label!.isNotEmpty) return label!;
    switch (linkType) {
      case 'website':
        return 'Website';
      case 'chesscom':
        return 'Chess.com';
      case 'lichess':
        return 'Lichess';
      case 'youtube':
        return 'YouTube';
      case 'twitter':
        return 'Twitter';
      case 'twitch':
        return 'Twitch';
      default:
        return linkType;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'link_type': linkType,
      'url': url,
      'label': label,
      'sort_order': sortOrder,
    };
  }
}

class LinkedChessAccount {
  final String id;
  final String platform;
  final String username;
  final String? avatarUrl;
  final DateTime linkedAt;
  final ChessAccountStats? stats;

  LinkedChessAccount({
    required this.id,
    required this.platform,
    required this.username,
    this.avatarUrl,
    required this.linkedAt,
    this.stats,
  });

  factory LinkedChessAccount.fromJson(Map<String, dynamic> json) {
    return LinkedChessAccount(
      id: json['id'] as String,
      platform: json['platform'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      linkedAt: DateTime.parse(json['linked_at'] as String),
      stats: json['stats'] != null
          ? ChessAccountStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayPlatform {
    switch (platform) {
      case 'chesscom':
        return 'Chess.com';
      case 'lichess':
        return 'Lichess';
      default:
        return platform;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'username': username,
      'avatar_url': avatarUrl,
      'linked_at': linkedAt.toIso8601String(),
      'stats': stats?.toJson(),
    };
  }
}

class ChessAccountStats {
  final int? rapidRating;
  final int? blitzRating;
  final int? bulletRating;
  final int? puzzleRating;

  ChessAccountStats({
    this.rapidRating,
    this.blitzRating,
    this.bulletRating,
    this.puzzleRating,
  });

  factory ChessAccountStats.fromJson(Map<String, dynamic> json) {
    return ChessAccountStats(
      rapidRating: json['rapid_rating'] as int?,
      blitzRating: json['blitz_rating'] as int?,
      bulletRating: json['bullet_rating'] as int?,
      puzzleRating: json['puzzle_rating'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rapid_rating': rapidRating,
      'blitz_rating': blitzRating,
      'bullet_rating': bulletRating,
      'puzzle_rating': puzzleRating,
    };
  }
}

class UserBoard {
  final String id;
  final String title;
  final String? coverImageUrl;
  final bool isPublic;
  final int viewsCount;
  final int likesCount;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;

  UserBoard({
    required this.id,
    required this.title,
    this.coverImageUrl,
    required this.isPublic,
    this.viewsCount = 0,
    this.likesCount = 0,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
  });

  factory UserBoard.fromJson(Map<String, dynamic> json) {
    return UserBoard(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: json['author_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_image_url': coverImageUrl,
      'is_public': isPublic,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
    };
  }
}

class GameReviewSummary {
  final String id;
  final String externalGameId;
  final double? accuracyWhite;
  final double? accuracyBlack;
  final DateTime reviewedAt;
  final int mistakesCount;

  GameReviewSummary({
    required this.id,
    required this.externalGameId,
    this.accuracyWhite,
    this.accuracyBlack,
    required this.reviewedAt,
    this.mistakesCount = 0,
  });

  factory GameReviewSummary.fromJson(Map<String, dynamic> json) {
    // Handle the count from personal_mistakes aggregate
    int mistakes = 0;
    if (json['personal_mistakes'] is List && (json['personal_mistakes'] as List).isNotEmpty) {
      final mistakesData = (json['personal_mistakes'] as List).first;
      if (mistakesData is Map && mistakesData['count'] != null) {
        mistakes = mistakesData['count'] as int;
      }
    }

    return GameReviewSummary(
      id: json['id'] as String,
      externalGameId: json['external_game_id'] as String,
      accuracyWhite: (json['accuracy_white'] as num?)?.toDouble(),
      accuracyBlack: (json['accuracy_black'] as num?)?.toDouble(),
      reviewedAt: DateTime.parse(json['reviewed_at'] as String),
      mistakesCount: mistakes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_game_id': externalGameId,
      'accuracy_white': accuracyWhite,
      'accuracy_black': accuracyBlack,
      'reviewed_at': reviewedAt.toIso8601String(),
      'personal_mistakes': [{'count': mistakesCount}],
    };
  }
}
