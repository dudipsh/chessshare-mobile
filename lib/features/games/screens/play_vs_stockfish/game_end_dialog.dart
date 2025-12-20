import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

void showGameEndDialog({
  required BuildContext context,
  required String result,
  required Side playerColor,
  required int moveCount,
  required VoidCallback onPlayAgain,
  required VoidCallback onDone,
}) {
  final playerWon = (result.contains('White wins') && playerColor == Side.white) ||
      (result.contains('Black wins') && playerColor == Side.black);
  final playerLost = (result.contains('White wins') && playerColor == Side.black) ||
      (result.contains('Black wins') && playerColor == Side.white);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        playerWon ? 'You Win!' : playerLost ? 'You Lost' : 'Draw',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            playerWon
                ? Icons.emoji_events
                : playerLost
                    ? Icons.sentiment_dissatisfied
                    : Icons.handshake,
            size: 64,
            color: playerWon
                ? Colors.amber
                : playerLost
                    ? Colors.red
                    : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            result,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            '$moveCount moves played',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onPlayAgain,
          child: const Text('Play Again'),
        ),
        ElevatedButton(
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<bool> showResignDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Resign?'),
      content: const Text('Are you sure you want to resign?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Resign'),
        ),
      ],
    ),
  );
  return result ?? false;
}
