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

  int get totalMoves => variations.fold(0, (sum, v) => sum + v.moveCount);
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
  final int moveCount;

  StudyVariation({
    required this.id,
    required this.boardId,
    required this.name,
    required this.pgn,
    this.startingFen,
    this.playerColor,
    this.position = 0,
    this.movesCompleted = 0,
    this.moveCount = 0,
  });

  factory StudyVariation.fromJson(Map<String, dynamic> json) {
    final pgn = json['pgn'] as String? ?? '';
    return StudyVariation(
      id: json['id'] as String,
      boardId: json['board_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Variation',
      pgn: pgn,
      startingFen: json['starting_fen'] as String?,
      playerColor: json['player_color'] as String?,
      position: json['position'] as int? ?? 0,
      movesCompleted: json['moves_completed'] as int? ?? 0,
      moveCount: _countMoves(pgn),
    );
  }

  double get completionPercentage =>
      moveCount > 0 ? (movesCompleted / moveCount * 100) : 0;

  bool get isCompleted => movesCompleted >= moveCount;

  static int _countMoves(String pgn) {
    if (pgn.isEmpty) return 0;
    // Count actual moves (exclude comments, annotations)
    final moves = pgn.split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty && !m.startsWith('{') && !m.contains('.'))
        .length;
    return moves;
  }
}
