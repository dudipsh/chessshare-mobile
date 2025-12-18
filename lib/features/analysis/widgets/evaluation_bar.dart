import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engine_evaluation.dart';
import '../providers/engine_provider.dart';

/// Horizontal evaluation bar showing engine score (displayed above the board)
class EvaluationBar extends ConsumerWidget {
  /// Height of the bar
  final double height;

  /// Whether to show the numeric evaluation on the sides
  final bool showEvaluation;

  /// Animation duration for bar changes
  final Duration animationDuration;

  /// Border radius
  final double borderRadius;

  const EvaluationBar({
    super.key,
    this.height = 8,
    this.showEvaluation = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(engineEvaluationProvider);
    final isAnalyzing = ref.watch(engineIsAnalyzingProvider);

    // 0.5 = equal, 1.0 = white winning, 0.0 = black winning
    final position = evaluation?.normalizedScore ?? 0.5;

    return SizedBox(
      height: showEvaluation ? height + 20 : height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Evaluation labels on sides
          if (showEvaluation)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Black side label
                  _EvalLabel(
                    evaluation: evaluation,
                    isBlackSide: true,
                    isAnalyzing: isAnalyzing,
                  ),
                  // White side label
                  _EvalLabel(
                    evaluation: evaluation,
                    isBlackSide: false,
                    isAnalyzing: isAnalyzing,
                  ),
                ],
              ),
            ),

          // The bar itself
          SizedBox(
            height: height,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius - 0.5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final whiteWidth = totalWidth * position;

                    return Stack(
                      children: [
                        // Black side (right)
                        Positioned.fill(
                          child: Container(color: Colors.grey.shade800),
                        ),
                        // White side (left)
                        AnimatedPositioned(
                          duration: animationDuration,
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
        ],
      ),
    );
  }
}

class _EvalLabel extends StatelessWidget {
  final EngineEvaluation? evaluation;
  final bool isBlackSide;
  final bool isAnalyzing;

  const _EvalLabel({
    required this.evaluation,
    required this.isBlackSide,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String text;
    if (evaluation == null) {
      text = isAnalyzing ? '...' : '';
    } else {
      // Show evaluation from the perspective asked
      final score = evaluation!.normalizedScore;
      if (isBlackSide) {
        // Black side - show disadvantage for white (advantage for black)
        if (score < 0.5) {
          text = _formatAdvantage(1 - score);
        } else {
          text = '';
        }
      } else {
        // White side - show advantage for white
        if (score > 0.5) {
          text = _formatAdvantage(score);
        } else {
          text = '';
        }
      }
    }

    // Only show on the winning side
    if (text.isEmpty && evaluation != null) {
      // Show the actual evaluation on the winning side
      if ((isBlackSide && evaluation!.normalizedScore < 0.5) ||
          (!isBlackSide && evaluation!.normalizedScore >= 0.5)) {
        text = evaluation!.displayString;
      }
    }

    return SizedBox(
      width: 50,
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: isBlackSide ? Colors.grey.shade600 : Colors.grey.shade800,
        ),
        textAlign: isBlackSide ? TextAlign.left : TextAlign.right,
      ),
    );
  }

  String _formatAdvantage(double normalizedScore) {
    // Convert normalized score (0.5-1.0) to pawns
    final advantage = (normalizedScore - 0.5) * 20; // Range 0-10
    if (advantage >= 10) return 'M'; // Mate territory
    return '+${advantage.toStringAsFixed(1)}';
  }
}

/// Compact horizontal evaluation bar (no labels, just the bar)
class CompactEvaluationBar extends ConsumerWidget {
  final double height;
  final Duration animationDuration;

  const CompactEvaluationBar({
    super.key,
    this.height = 6,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(engineEvaluationProvider);
    final position = evaluation?.normalizedScore ?? 0.5;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final whiteWidth = constraints.maxWidth * position;

            return Stack(
              children: [
                Positioned.fill(
                  child: Container(color: Colors.grey.shade700),
                ),
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: whiteWidth,
                  child: Container(color: Colors.white),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Vertical evaluation bar (alternative for side display)
class VerticalEvaluationBar extends ConsumerWidget {
  final double width;
  final bool showEvaluation;
  final Duration animationDuration;

  const VerticalEvaluationBar({
    super.key,
    this.width = 24,
    this.showEvaluation = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(engineEvaluationProvider);
    final isAnalyzing = ref.watch(engineIsAnalyzingProvider);
    final position = evaluation?.normalizedScore ?? 0.5;

    return SizedBox(
      width: width,
      child: Column(
        children: [
          if (showEvaluation)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                evaluation?.displayString ?? (isAnalyzing ? '...' : '-'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final whiteHeight = constraints.maxHeight * position;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(color: Colors.grey.shade800),
                        ),
                        AnimatedPositioned(
                          duration: animationDuration,
                          curve: Curves.easeInOut,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: whiteHeight,
                          child: Container(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
