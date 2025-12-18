import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engine_evaluation.dart';
import '../providers/engine_provider.dart';

/// Vertical evaluation bar showing engine score
class EvaluationBar extends ConsumerWidget {
  /// Width of the bar
  final double width;

  /// Whether to show the numeric evaluation
  final bool showEvaluation;

  /// Animation duration for bar changes
  final Duration animationDuration;

  const EvaluationBar({
    super.key,
    this.width = 24,
    this.showEvaluation = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(engineEvaluationProvider);
    final isAnalyzing = ref.watch(engineIsAnalyzingProvider);

    return SizedBox(
      width: width,
      child: Column(
        children: [
          // Evaluation text at top
          if (showEvaluation)
            _EvaluationLabel(
              evaluation: evaluation,
              isAnalyzing: isAnalyzing,
            ),

          // The bar itself
          Expanded(
            child: _EvaluationBarBody(
              evaluation: evaluation,
              animationDuration: animationDuration,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationLabel extends StatelessWidget {
  final EngineEvaluation? evaluation;
  final bool isAnalyzing;

  const _EvaluationLabel({
    required this.evaluation,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String text;
    if (evaluation == null) {
      text = isAnalyzing ? '...' : '-';
    } else {
      text = evaluation!.displayString;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EvaluationBarBody extends StatelessWidget {
  final EngineEvaluation? evaluation;
  final Duration animationDuration;

  const _EvaluationBarBody({
    required this.evaluation,
    required this.animationDuration,
  });

  @override
  Widget build(BuildContext context) {
    // 0.5 = equal, 1.0 = white winning, 0.0 = black winning
    final position = evaluation?.normalizedScore ?? 0.5;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final whiteHeight = totalHeight * position;

            return Stack(
              children: [
                // Black side (top)
                Positioned.fill(
                  child: Container(color: Colors.grey.shade800),
                ),
                // White side (bottom)
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: whiteHeight,
                  child: Container(color: Colors.white),
                ),
                // Center line
                Positioned(
                  left: 0,
                  right: 0,
                  top: totalHeight / 2 - 0.5,
                  child: Container(
                    height: 1,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Horizontal evaluation bar (alternative layout)
class HorizontalEvaluationBar extends ConsumerWidget {
  final double height;
  final bool showEvaluation;
  final Duration animationDuration;

  const HorizontalEvaluationBar({
    super.key,
    this.height = 24,
    this.showEvaluation = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(engineEvaluationProvider);
    final isAnalyzing = ref.watch(engineIsAnalyzingProvider);

    // 0.5 = equal, 1.0 = white winning, 0.0 = black winning
    final position = evaluation?.normalizedScore ?? 0.5;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          // Evaluation text
          if (showEvaluation)
            SizedBox(
              width: 48,
              child: Text(
                evaluation?.displayString ?? (isAnalyzing ? '...' : '-'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

          // The bar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
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
                          child: Container(color: Colors.white),
                        ),
                        // Center line
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: totalWidth / 2 - 0.5,
                          child: Container(
                            width: 1,
                            color: Colors.grey.shade500,
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
