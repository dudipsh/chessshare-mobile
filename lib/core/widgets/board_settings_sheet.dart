import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/board_settings_provider.dart';

/// Shows a bottom sheet with board settings options
void showBoardSettingsSheet({
  required BuildContext context,
  required WidgetRef ref,
  VoidCallback? onFlipBoard,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _BoardSettingsSheet(
      onFlipBoard: onFlipBoard,
    ),
  );
}

class _BoardSettingsSheet extends ConsumerWidget {
  final VoidCallback? onFlipBoard;

  const _BoardSettingsSheet({this.onFlipBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(boardSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Board Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Flip Board
                    if (onFlipBoard != null)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.swap_vert,
                          label: 'Flip Board',
                          onTap: () {
                            onFlipBoard!();
                            Navigator.pop(context);
                          },
                          isDark: isDark,
                        ),
                      ),
                    if (onFlipBoard != null) const SizedBox(width: 12),
                    // Mute/Unmute
                    Expanded(
                      child: _ActionButton(
                        icon: settings.isMuted ? Icons.volume_off : Icons.volume_up,
                        label: settings.isMuted ? 'Unmute' : 'Mute',
                        onTap: () {
                          ref.read(boardSettingsProvider.notifier).toggleMute();
                        },
                        isDark: isDark,
                        isActive: settings.isMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Piece Set Section
              _SectionHeader(title: 'Piece Style', isDark: isDark),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ChessPieceSet.values.length,
                  itemBuilder: (context, index) {
                    final pieceSet = ChessPieceSet.values[index];
                    final isSelected = settings.pieceSet == pieceSet;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(boardSettingsProvider.notifier).setPieceSet(pieceSet);
                        },
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                                : (isDark ? Colors.white10 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Piece preview (using text for now)
                              Text(
                                '\u265A', // Chess king unicode
                                style: TextStyle(
                                  fontSize: 24,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pieceSet.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Board Colors Section
              _SectionHeader(title: 'Board Colors', isDark: isDark),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: BoardColorScheme.values.length,
                  itemBuilder: (context, index) {
                    final colorScheme = BoardColorScheme.values[index];
                    final isSelected = settings.colorScheme == colorScheme;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(boardSettingsProvider.notifier).setColorScheme(colorScheme);
                        },
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                : Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Color preview (checkerboard pattern)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Container(color: colorScheme.lightSquare),
                                            ),
                                            Expanded(
                                              child: Container(color: colorScheme.darkSquare),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Container(color: colorScheme.darkSquare),
                                            ),
                                            Expanded(
                                              child: Container(color: colorScheme.lightSquare),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                colorScheme.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Theme.of(context).primaryColor, width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? Theme.of(context).primaryColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
