import 'package:flutter/material.dart';

/// Control buttons for Study board with consistent gray color scheme.
/// All buttons use the same gray palette for visual consistency.
class ControlButtons extends StatelessWidget {
  final int moveIndex;
  final int totalMoves;
  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback? onHint;
  final VoidCallback onFlip;
  final VoidCallback onReset;
  final bool isDark;

  const ControlButtons({
    super.key,
    required this.moveIndex,
    required this.totalMoves,
    required this.isPlaying,
    required this.onBack,
    required this.onForward,
    this.onHint,
    required this.onFlip,
    required this.onReset,
    required this.isDark,
  });

  // Gray color scheme for consistent button styling
  Color get _buttonColor => isDark ? Colors.grey.shade600 : Colors.grey.shade700;
  Color get _buttonBgEnabled => isDark
      ? Colors.grey.shade800
      : Colors.grey.shade200;
  Color get _buttonBgDisabled => Colors.transparent;
  Color get _iconDisabled => isDark ? Colors.grey.shade700 : Colors.grey.shade400;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(Icons.skip_previous_rounded, 'Back', moveIndex > 0 ? onBack : null),
          _buildButton(Icons.lightbulb_rounded, 'Hint', isPlaying ? onHint : null),
          _buildButton(Icons.sync_rounded, 'Flip', onFlip),
          _buildButton(Icons.replay_rounded, 'Reset', onReset),
          _buildButton(Icons.skip_next_rounded, 'Next', moveIndex < totalMoves ? onForward : null),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEnabled ? _buttonBgEnabled : _buttonBgDisabled,
              borderRadius: BorderRadius.circular(10),
              border: isEnabled
                  ? Border.all(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
              icon,
              size: 24,
              color: isEnabled ? _buttonColor : _iconDisabled,
            ),
          ),
        ),
      ),
    );
  }
}
