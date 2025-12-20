import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

class GameInfo extends StatelessWidget {
  final int moveCount;
  final Side turn;
  final bool isCheck;

  const GameInfo({
    super.key,
    required this.moveCount,
    required this.turn,
    required this.isCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _GameInfoItem(label: 'Moves', value: '$moveCount'),
          _GameInfoItem(
            label: 'Turn',
            value: turn == Side.white ? 'White' : 'Black',
          ),
          _GameInfoItem(
            label: 'Check',
            value: isCheck ? 'Yes' : 'No',
          ),
        ],
      ),
    );
  }
}

class _GameInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _GameInfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
