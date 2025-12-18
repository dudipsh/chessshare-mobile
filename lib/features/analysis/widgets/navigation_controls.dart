import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';

class NavigationControls extends StatelessWidget {
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;

  const NavigationControls({
    super.key,
    this.onFirst,
    this.onPrevious,
    this.onNext,
    this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildButton(
            icon: Icons.first_page,
            onPressed: onFirst,
            tooltip: 'First move',
          ),
          const SizedBox(width: 8),
          _buildButton(
            icon: Icons.chevron_left,
            onPressed: onPrevious,
            tooltip: 'Previous move',
            large: true,
          ),
          const SizedBox(width: 8),
          _buildButton(
            icon: Icons.chevron_right,
            onPressed: onNext,
            tooltip: 'Next move',
            large: true,
          ),
          const SizedBox(width: 8),
          _buildButton(
            icon: Icons.last_page,
            onPressed: onLast,
            tooltip: 'Last move',
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool large = false,
  }) {
    final isEnabled = onPressed != null;
    final size = large ? 48.0 : 40.0;
    final iconSize = large ? 28.0 : 24.0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.accent.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: isEnabled
                  ? AppColors.accent
                  : Colors.white.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}

// Auto-play controls for future use
class AutoPlayControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  const AutoPlayControls({
    super.key,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.speed,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: onTogglePlay,
          color: AppColors.accent,
        ),
        const SizedBox(width: 8),
        Text(
          '${speed.toStringAsFixed(1)}x',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        SizedBox(
          width: 100,
          child: Slider(
            value: speed,
            min: 0.5,
            max: 3.0,
            divisions: 5,
            onChanged: onSpeedChanged,
            activeColor: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
