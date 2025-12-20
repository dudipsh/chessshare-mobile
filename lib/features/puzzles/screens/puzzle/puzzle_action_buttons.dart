import 'package:flutter/material.dart';

class PuzzleActionButtons extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onDone;

  const PuzzleActionButtons({
    super.key,
    required this.onTryAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onTryAgain,
              child: const Text('Try Again'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
