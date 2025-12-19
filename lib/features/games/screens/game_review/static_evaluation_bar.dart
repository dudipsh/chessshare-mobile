import 'package:flutter/material.dart';

class StaticEvaluationBar extends StatelessWidget {
  final int? evalCp;
  final double width;

  const StaticEvaluationBar({
    super.key,
    this.evalCp,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Convert centipawns to normalized score (0.0 = black winning, 0.5 = equal, 1.0 = white winning)
    double normalizedScore = 0.5;
    if (evalCp != null) {
      final clampedCp = evalCp!.clamp(-1000, 1000);
      normalizedScore = 0.5 + (clampedCp / 2000);
      normalizedScore = normalizedScore.clamp(0.05, 0.95);
    }

    // Format evaluation string
    String evalString = '';
    if (evalCp != null) {
      if (evalCp!.abs() >= 10000) {
        final mateIn = ((10000 - evalCp!.abs()) / 2).ceil();
        evalString = evalCp! > 0 ? 'M$mateIn' : '-M$mateIn';
      } else {
        final pawns = evalCp! / 100;
        evalString = pawns >= 0 ? '+${pawns.toStringAsFixed(1)}' : pawns.toStringAsFixed(1);
      }
    }

    return SizedBox(
      width: width,
      height: 20,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              normalizedScore > 0.5 ? evalString : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3.5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final whiteWidth = constraints.maxWidth * normalizedScore;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(color: Colors.grey.shade800),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: whiteWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 2,
                                  offset: const Offset(1, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              normalizedScore < 0.5 ? evalString : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
