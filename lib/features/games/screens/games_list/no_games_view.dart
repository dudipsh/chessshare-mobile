import 'package:flutter/material.dart';

class NoGamesView extends StatelessWidget {
  final VoidCallback onImportPressed;

  const NoGamesView({
    super.key,
    required this.onImportPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No games found'),
          const SizedBox(height: 8),
          Text(
            'Try importing games or check your username',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onImportPressed,
            icon: const Icon(Icons.add),
            label: const Text('Import Games'),
          ),
        ],
      ),
    );
  }
}
