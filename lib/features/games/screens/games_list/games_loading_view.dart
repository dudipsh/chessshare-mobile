import 'package:flutter/material.dart';

class GamesLoadingView extends StatelessWidget {
  final bool isImporting;
  final String? importingPlatform;
  final int importProgress;
  final int importTotal;

  const GamesLoadingView({
    super.key,
    this.isImporting = false,
    this.importingPlatform,
    this.importProgress = 0,
    this.importTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (isImporting) ...[
            const SizedBox(height: 16),
            Text(
              'Importing from $importingPlatform...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (importTotal > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$importProgress/$importTotal',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
