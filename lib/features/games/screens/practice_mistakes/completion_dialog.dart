import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../gamification/models/xp_models.dart';
import '../../../gamification/widgets/xp_popup.dart';

void showPracticeCompletionDialog({
  required BuildContext context,
  required int correctCount,
  required int total,
  required VoidCallback onTryAgain,
  required VoidCallback onDone,
  int? totalXpEarned,
  int? previousTotalXp,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PracticeCompletionDialogContent(
      correctCount: correctCount,
      total: total,
      onTryAgain: onTryAgain,
      onDone: onDone,
      totalXpEarned: totalXpEarned,
      previousTotalXp: previousTotalXp,
    ),
  );
}

class _PracticeCompletionDialogContent extends StatefulWidget {
  final int correctCount;
  final int total;
  final VoidCallback onTryAgain;
  final VoidCallback onDone;
  final int? totalXpEarned;
  final int? previousTotalXp;

  const _PracticeCompletionDialogContent({
    required this.correctCount,
    required this.total,
    required this.onTryAgain,
    required this.onDone,
    this.totalXpEarned,
    this.previousTotalXp,
  });

  @override
  State<_PracticeCompletionDialogContent> createState() =>
      _PracticeCompletionDialogContentState();
}

class _PracticeCompletionDialogContentState
    extends State<_PracticeCompletionDialogContent> {
  late ConfettiController _confettiController;
  bool _showedXpPopup = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Start confetti immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();

      // Show XP popup after a short delay
      if (widget.totalXpEarned != null && widget.totalXpEarned! > 0 && !_showedXpPopup) {
        _showedXpPopup = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            XpPopup.show(
              context,
              result: XpAwardResult.local(
                xpAwarded: widget.totalXpEarned!,
                oldTotalXp: widget.previousTotalXp ?? 0,
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.total > 0 ? widget.correctCount / widget.total * 100 : 0;

    return Stack(
      children: [
        AlertDialog(
          title: const Text('Practice Complete!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                '${widget.correctCount} / ${widget.total} correct',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Accuracy: ${accuracy.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              if (widget.totalXpEarned != null && widget.totalXpEarned! > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: AppColors.primary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '+${widget.totalXpEarned} XP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: widget.onTryAgain, child: const Text('Try Again')),
            ElevatedButton(onPressed: widget.onDone, child: const Text('Done')),
          ],
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.yellow,
            ],
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            gravity: 0.2,
          ),
        ),
      ],
    );
  }
}
