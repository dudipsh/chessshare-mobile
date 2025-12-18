import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/games_provider.dart';

class ImportScreen extends ConsumerStatefulWidget {
  final String platform; // 'chesscom' or 'lichess'

  const ImportScreen({super.key, required this.platform});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _usernameController = TextEditingController();
  bool _saveUsername = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill with saved username if available
    final profile = ref.read(authProvider).profile;
    if (widget.platform == 'chesscom' && profile?.chessComUsername != null) {
      _usernameController.text = profile!.chessComUsername!;
    } else if (widget.platform == 'lichess' && profile?.lichessUsername != null) {
      _usernameController.text = profile!.lichessUsername!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String get _platformName => widget.platform == 'chesscom' ? 'Chess.com' : 'Lichess';

  Future<void> _startImport() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    final gamesNotifier = ref.read(gamesProvider.notifier);

    // Save username if requested
    if (_saveUsername && ref.read(authProvider).isAuthenticated) {
      final authNotifier = ref.read(authProvider.notifier);
      if (widget.platform == 'chesscom') {
        await authNotifier.updateChessComUsername(username);
      } else {
        await authNotifier.updateLichessUsername(username);
      }
    }

    // Start import
    if (widget.platform == 'chesscom') {
      await gamesNotifier.importFromChessCom(username);
    } else {
      await gamesNotifier.importFromLichess(username);
    }

    // Check if import was successful
    final state = ref.read(gamesProvider);
    if (!state.isImporting && state.error == null && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamesState = ref.watch(gamesProvider);
    final isImporting = gamesState.isImporting;

    return Scaffold(
      appBar: AppBar(
        title: Text('Import from $_platformName'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  widget.platform == 'chesscom' ? Icons.public : Icons.public,
                  size: 40,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Username input
            Text(
              '$_platformName Username',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              enabled: !isImporting,
              decoration: InputDecoration(
                hintText: 'Enter your username',
                filled: true,
                fillColor: AppColors.primaryLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _startImport(),
            ),
            const SizedBox(height: 16),

            // Save username checkbox
            if (ref.watch(authProvider).isAuthenticated)
              CheckboxListTile(
                value: _saveUsername,
                onChanged: isImporting
                    ? null
                    : (value) => setState(() => _saveUsername = value ?? true),
                title: const Text('Remember username'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

            const SizedBox(height: 24),

            // Import button or progress
            if (isImporting) ...[
              _buildImportProgress(gamesState),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _usernameController.text.isNotEmpty
                      ? _startImport
                      : null,
                  child: const Text('Import Games'),
                ),
              ),
            ],

            // Error message
            if (gamesState.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        gamesState.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Info text
            Text(
              'We will import your recent games from $_platformName. '
              'This may take a moment depending on how many games you have.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportProgress(GamesState state) {
    final progress = state.importTotal > 0
        ? state.importProgress / state.importTotal
        : 0.0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.primaryLight,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
        ),
        const SizedBox(height: 16),
        Text(
          'Importing from ${state.importingPlatform}...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (state.importTotal > 0)
          Text(
            '${state.importProgress} / ${state.importTotal}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}
