import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class ReviewActionButtons extends StatelessWidget {
  final int mistakesCount;
  final VoidCallback? onPractice;
  final VoidCallback onPlayEngine;
  final bool isPracticeLoading;

  const ReviewActionButtons({
    super.key,
    required this.mistakesCount,
    this.onPractice,
    required this.onPlayEngine,
    this.isPracticeLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Practice button
          Expanded(
            child: _ActionButton(
              icon: Icons.fitness_center,
              title: 'Practice',
              badge: mistakesCount > 0 ? '$mistakesCount' : null,
              gradientColors: const [
                Color(0xFFFF6B6B),
                Color(0xFFFF8E8E),
              ],
              isDark: isDark,
              isEnabled: mistakesCount > 0 && !isPracticeLoading,
              isLoading: isPracticeLoading,
              onTap: mistakesCount > 0 && !isPracticeLoading ? onPractice : null,
            ),
          ),
          const SizedBox(width: 10),
          // Play vs Engine button
          Expanded(
            child: _ActionButton(
              icon: Icons.smart_toy,
              title: 'Play Engine',
              gradientColors: [
                AppColors.primary,
                AppColors.primaryLight,
              ],
              isDark: isDark,
              isEnabled: true,
              onTap: onPlayEngine,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final List<Color> gradientColors;
  final bool isDark;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    this.badge,
    required this.gradientColors,
    required this.isDark,
    required this.isEnabled,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isEnabled ? 1.0 : 0.4;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: opacity,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? gradientColors.map((c) => c.withValues(alpha: 0.3)).toList()
                    : [
                        gradientColors[0].withValues(alpha: 0.15),
                        gradientColors[1].withValues(alpha: 0.08),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withValues(alpha: isDark ? 0.15 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : gradientColors[0],
                      ),
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: isDark ? Colors.white : gradientColors[0],
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  isLoading ? 'Loading...' : title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (badge != null && !isLoading) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : gradientColors[0].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : gradientColors[0],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
