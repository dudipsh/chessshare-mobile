enum GamePlatform { chesscom, lichess }

enum GameResult { win, loss, draw }

enum GameSpeed { bullet, blitz, rapid, classical, correspondence }

class ChessGame {
  final String id;
  final String externalId;
  final GamePlatform platform;
  final String pgn;
  final String playerColor; // 'white' or 'black'
  final GameResult result;
  final GameSpeed speed;
  final String? timeControl;
  final DateTime playedAt;
  final String opponentUsername;
  final int? opponentRating;
  final int? playerRating;
  final String? openingName;
  final String? openingEco;
  // Analysis data
  final double? accuracyWhite;
  final double? accuracyBlack;
  final bool isAnalyzed;
  final int puzzleCount; // Number of puzzles generated from analysis

  ChessGame({
    required this.id,
    required this.externalId,
    required this.platform,
    required this.pgn,
    required this.playerColor,
    required this.result,
    required this.speed,
    this.timeControl,
    required this.playedAt,
    required this.opponentUsername,
    this.opponentRating,
    this.playerRating,
    this.openingName,
    this.openingEco,
    this.accuracyWhite,
    this.accuracyBlack,
    this.isAnalyzed = false,
    this.puzzleCount = 0,
  });

  double? get playerAccuracy =>
      playerColor == 'white' ? accuracyWhite : accuracyBlack;

  factory ChessGame.fromChessCom(Map<String, dynamic> json, String playerUsername) {
    final white = json['white'] as Map<String, dynamic>;
    final black = json['black'] as Map<String, dynamic>;

    final isWhite = (white['username'] as String).toLowerCase() ==
                    playerUsername.toLowerCase();

    final playerData = isWhite ? white : black;
    final opponentData = isWhite ? black : white;

    GameResult result;
    final playerResult = playerData['result'] as String;
    if (playerResult == 'win') {
      result = GameResult.win;
    } else if (['checkmated', 'timeout', 'resigned', 'lose', 'abandoned'].contains(playerResult)) {
      result = GameResult.loss;
    } else {
      result = GameResult.draw;
    }

    GameSpeed speed;
    final timeClass = json['time_class'] as String? ?? 'rapid';
    switch (timeClass) {
      case 'bullet':
        speed = GameSpeed.bullet;
        break;
      case 'blitz':
        speed = GameSpeed.blitz;
        break;
      case 'rapid':
        speed = GameSpeed.rapid;
        break;
      case 'classical':
      case 'standard':
        speed = GameSpeed.classical;
        break;
      case 'daily':
        speed = GameSpeed.correspondence;
        break;
      default:
        speed = GameSpeed.rapid;
    }

    return ChessGame(
      id: json['uuid'] as String? ?? json['url'] as String,
      externalId: json['uuid'] as String? ?? json['url'] as String,
      platform: GamePlatform.chesscom,
      pgn: json['pgn'] as String? ?? '',
      playerColor: isWhite ? 'white' : 'black',
      result: result,
      speed: speed,
      timeControl: json['time_control'] as String?,
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['end_time'] as int) * 1000,
      ),
      opponentUsername: opponentData['username'] as String,
      opponentRating: opponentData['rating'] as int?,
      playerRating: playerData['rating'] as int?,
      openingName: _extractOpening(json['pgn'] as String?),
      openingEco: _extractEco(json['pgn'] as String?),
    );
  }

  factory ChessGame.fromLichess(Map<String, dynamic> json, String playerUsername) {
    final players = json['players'] as Map<String, dynamic>;
    final white = players['white'] as Map<String, dynamic>;
    final black = players['black'] as Map<String, dynamic>;

    final whiteUser = white['user'] as Map<String, dynamic>?;
    final blackUser = black['user'] as Map<String, dynamic>?;

    final isWhite = (whiteUser?['name'] as String?)?.toLowerCase() ==
                    playerUsername.toLowerCase();

    final playerData = isWhite ? white : black;
    final opponentData = isWhite ? black : white;
    final opponentUser = isWhite ? blackUser : whiteUser;

    GameResult result;
    final winner = json['winner'] as String?;
    if (winner == null) {
      result = GameResult.draw;
    } else if ((winner == 'white' && isWhite) || (winner == 'black' && !isWhite)) {
      result = GameResult.win;
    } else {
      result = GameResult.loss;
    }

    GameSpeed speed;
    final speedStr = json['speed'] as String? ?? 'rapid';
    switch (speedStr) {
      case 'ultraBullet':
      case 'bullet':
        speed = GameSpeed.bullet;
        break;
      case 'blitz':
        speed = GameSpeed.blitz;
        break;
      case 'rapid':
        speed = GameSpeed.rapid;
        break;
      case 'classical':
        speed = GameSpeed.classical;
        break;
      case 'correspondence':
        speed = GameSpeed.correspondence;
        break;
      default:
        speed = GameSpeed.rapid;
    }

    final opening = json['opening'] as Map<String, dynamic>?;

    return ChessGame(
      id: json['id'] as String,
      externalId: json['id'] as String,
      platform: GamePlatform.lichess,
      pgn: json['pgn'] as String? ?? _movesToPgn(json['moves'] as String?),
      playerColor: isWhite ? 'white' : 'black',
      result: result,
      speed: speed,
      timeControl: json['clock'] != null
          ? '${(json['clock'] as Map)['initial']}+${(json['clock'] as Map)['increment']}'
          : null,
      playedAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      opponentUsername: opponentUser?['name'] as String? ?? 'Anonymous',
      opponentRating: opponentData['rating'] as int?,
      playerRating: playerData['rating'] as int?,
      openingName: opening?['name'] as String?,
      openingEco: opening?['eco'] as String?,
    );
  }

  static String? _extractOpening(String? pgn) {
    if (pgn == null) return null;
    final match = RegExp(r'\[ECOUrl "https://www\.chess\.com/openings/([^"]+)"\]').firstMatch(pgn);
    if (match != null) {
      return match.group(1)?.replaceAll('-', ' ');
    }
    final openingMatch = RegExp(r'\[Opening "([^"]+)"\]').firstMatch(pgn);
    return openingMatch?.group(1);
  }

  static String? _extractEco(String? pgn) {
    if (pgn == null) return null;
    final match = RegExp(r'\[ECO "([^"]+)"\]').firstMatch(pgn);
    return match?.group(1);
  }

  static String _movesToPgn(String? moves) {
    if (moves == null || moves.isEmpty) return '';
    final moveList = moves.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < moveList.length; i++) {
      if (i % 2 == 0) {
        buffer.write('${(i ~/ 2) + 1}. ');
      }
      buffer.write('${moveList[i]} ');
    }
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_id': externalId,
      'platform': platform.name,
      'pgn': pgn,
      'player_color': playerColor,
      'result': result.name,
      'speed': speed.name,
      'time_control': timeControl,
      'played_at': playedAt.toIso8601String(),
      'opponent_username': opponentUsername,
      'opponent_rating': opponentRating,
      'player_rating': playerRating,
      'opening_name': openingName,
      'opening_eco': openingEco,
      'accuracy_white': accuracyWhite,
      'accuracy_black': accuracyBlack,
      'is_analyzed': isAnalyzed,
      'puzzle_count': puzzleCount,
    };
  }
}
