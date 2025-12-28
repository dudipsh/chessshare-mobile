import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuickAccessButtons extends StatelessWidget {
  const QuickAccessButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickAccessCard(
              icon: Icons.extension,
              title: 'My Puzzles',
              subtitle: 'Train your brain',
              isDark: isDark,
              gradientColors: const [
                Color(0xFFFF9F43),
                Color(0xFFFFBE76),
              ],
              backgroundPattern: _PuzzlePattern(),
              onTap: () => context.pushNamed('puzzles'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAccessCard(
              icon: Icons.insights,
              title: 'Insights',
              subtitle: 'Analyze performance',
              isDark: isDark,
              gradientColors: const [
                Color(0xFF5C9CE6),
                Color(0xFF74B9FF),
              ],
              backgroundPattern: _InsightsPattern(),
              onTap: () => context.pushNamed('insights'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final List<Color> gradientColors;
  final Widget backgroundPattern;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.gradientColors,
    required this.backgroundPattern,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
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
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: backgroundPattern,
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Icon(
                      icon,
                      color: isDark ? Colors.white : gradientColors[0],
                      size: 26,
                    ),
                    // Title and Subtitle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Decorative pattern for Puzzles card
class _PuzzlePattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PuzzlePainter(),
      size: Size.infinite,
    );
  }
}

class _PuzzlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw puzzle piece shapes
    final path = Path();

    // Large puzzle piece in corner
    path.addOval(Rect.fromCircle(
      center: Offset(size.width * 0.85, size.height * 0.2),
      radius: 25,
    ));

    path.addOval(Rect.fromCircle(
      center: Offset(size.width * 0.7, size.height * 0.7),
      radius: 15,
    ));

    path.addOval(Rect.fromCircle(
      center: Offset(size.width * 0.95, size.height * 0.6),
      radius: 20,
    ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Decorative pattern for Insights card
class _InsightsPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InsightsPainter(),
      size: Size.infinite,
    );
  }
}

class _InsightsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw chart-like lines
    final path = Path();

    // Rising line chart
    path.moveTo(size.width * 0.6, size.height * 0.8);
    path.lineTo(size.width * 0.7, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.9, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.2);

    canvas.drawPath(path, paint);

    // Draw dots at data points
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.6), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.3), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
