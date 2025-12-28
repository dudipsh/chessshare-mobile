import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class ReviewActionButtons extends StatelessWidget {
  final int mistakesCount;
  final VoidCallback? onPractice;
  final VoidCallback onPlayEngine;

  const ReviewActionButtons({
    super.key,
    required this.mistakesCount,
    this.onPractice,
    required this.onPlayEngine,
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
            child: _ActionCard(
              icon: Icons.fitness_center,
              title: 'Practice',
              subtitle: '$mistakesCount mistakes',
              gradientColors: const [
                Color(0xFFFF6B6B),
                Color(0xFFFF8E8E),
              ],
              isDark: isDark,
              isEnabled: mistakesCount > 0,
              onTap: mistakesCount > 0 ? onPractice : null,
            ),
          ),
          const SizedBox(width: 12),
          // Play vs Engine button
          Expanded(
            child: _ActionCard(
              icon: Icons.smart_toy,
              title: 'Play Engine',
              subtitle: 'From here',
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final bool isDark;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.isDark,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isEnabled ? 1.0 : 0.4;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: opacity,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                  color: gradientColors[0].withValues(alpha: isDark ? 0.2 : 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Colors.white : gradientColors[0],
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
