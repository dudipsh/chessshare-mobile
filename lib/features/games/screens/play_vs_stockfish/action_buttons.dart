import 'package:flutter/material.dart';

class GameActionButtons extends StatelessWidget {
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback? onResign;

  const GameActionButtons({
    super.key,
    required this.canUndo,
    required this.onUndo,
    required this.onReset,
    required this.onResign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onResign,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.flag),
              label: const Text('Resign'),
            ),
          ),
        ],
      ),
    );
  }
}
