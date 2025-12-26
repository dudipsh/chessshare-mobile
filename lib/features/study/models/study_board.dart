/// Study board model
class StudyBoard {
  final String id;
  final String title;
  final String? description;
  final String ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? coverImageUrl;
  final bool isPublic;
  final int viewsCount;
  final int likesCount;
  final bool userLiked;
  final String? startingFen;
  final List<StudyVariation> variations;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyBoard({
    required this.id,
    required this.title,
    this.description,
    required this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    this.coverImageUrl,
    this.isPublic = true,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.userLiked = false,
    this.startingFen,
    this.variations = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyBoard.fromJson(Map<String, dynamic> json) {
    return StudyBoard(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      ownerId: json['owner_id'] as String,
      ownerName: json['author']?['full_name'] as String?,
      ownerAvatarUrl: json['author']?['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      userLiked: json['user_liked'] as bool? ?? false,
      startingFen: json['starting_fen'] as String?,
      variations: (json['variations'] as List<dynamic>?)
              ?.map((v) => StudyVariation.fromJson(v))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Parse from RPC response format (flattened structure)
  factory StudyBoard.fromRpcJson(Map<String, dynamic> json) {
    return StudyBoard(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_full_name'] as String? ?? json['author_name'] as String? ?? json['author']?['full_name'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String? ?? json['author_avatar'] as String? ?? json['author']?['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      userLiked: json['user_liked'] as bool? ?? false,
      startingFen: json['starting_fen'] as String?,
      variations: _parseVariations(json),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at'] ?? json['created_at']),
    );
  }

  static List<StudyVariation> _parseVariations(Map<String, dynamic> json) {
    // RPC might return variations in different formats
    if (json['variations'] != null && json['variations'] is List) {
      return (json['variations'] as List)
          .map((v) => StudyVariation.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    if (json['variations_list'] != null && json['variations_list'] is List) {
      return (json['variations_list'] as List)
          .map((v) => StudyVariation.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    return DateTime.tryParse(date.toString()) ?? DateTime.now();
  }

  int get totalMoves => variations.fold(0, (sum, v) => sum + v.moveCount);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'owner_id': ownerId,
      'author': {
        'full_name': ownerName,
        'avatar_url': ownerAvatarUrl,
      },
      'cover_image_url': coverImageUrl,
      'is_public': isPublic,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'user_liked': userLiked,
      'starting_fen': startingFen,
      'variations': variations.map((v) => v.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Study variation (a line of moves to practice)
class StudyVariation {
  final String id;
  final String boardId;
  final String name;
  final String pgn;
  final String? startingFen;
  final String? playerColor;
  final int position;
  final int movesCompleted;
  final int totalMoves;
  final bool isCompleted;
  final double completionPercentage;

  StudyVariation({
    required this.id,
    required this.boardId,
    required this.name,
    required this.pgn,
    this.startingFen,
    this.playerColor,
    this.position = 0,
    this.movesCompleted = 0,
    this.totalMoves = 0,
    this.isCompleted = false,
    this.completionPercentage = 0,
  });

  factory StudyVariation.fromJson(Map<String, dynamic> json) {
    final pgn = json['pgn'] as String? ?? '';

    // Parse progress from nested object if available
    final progress = json['progress'] as Map<String, dynamic>?;
    final movesCompleted = progress?['moves_completed'] as int? ??
                           json['moves_completed'] as int? ?? 0;
    final totalMoves = progress?['total_moves'] as int? ??
                       json['total_moves'] as int? ??
                       _countMoves(pgn);
    final isCompleted = progress?['is_completed'] as bool? ??
                        json['is_completed'] as bool? ?? false;
    final completionPct = progress?['completion_percentage'] as num? ??
                          json['completion_percentage'] as num? ?? 0;

    return StudyVariation(
      id: json['id'] as String,
      boardId: json['board_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Variation',
      pgn: pgn,
      startingFen: json['starting_fen'] as String?,
      playerColor: json['player_color'] as String?,
      position: json['position'] as int? ?? 0,
      movesCompleted: movesCompleted,
      totalMoves: totalMoves,
      isCompleted: isCompleted,
      completionPercentage: completionPct.toDouble(),
    );
  }

  int get moveCount => totalMoves;

  static int _countMoves(String pgn) {
    if (pgn.isEmpty) return 0;
    // Count actual moves (exclude comments, annotations)
    final moves = pgn.split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty && !m.startsWith('{') && !m.contains('.'))
        .length;
    return moves;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'name': name,
      'pgn': pgn,
      'starting_fen': startingFen,
      'player_color': playerColor,
      'position': position,
      'moves_completed': movesCompleted,
      'total_moves': totalMoves,
      'is_completed': isCompleted,
      'completion_percentage': completionPercentage,
    };
  }
}
