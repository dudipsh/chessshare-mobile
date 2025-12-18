import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/colors.dart';

class GameCard extends StatelessWidget {
  final String opponent;
  final String result;
  final double accuracy;
  final String opening;
  final DateTime date;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.opponent,
    required this.result,
    required this.accuracy,
    required this.opening,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resultColor = AppColors.getResultColor(result);
    final resultText = result[0].toUpperCase() + result.substring(1);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Result indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: resultColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'vs $opponent',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: resultColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resultText,
                            style: TextStyle(
                              color: resultColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opening,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(date),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Accuracy
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _getAccuracyColor(accuracy),
                    ),
                  ),
                  Text(
                    'Accuracy',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return AppColors.brilliant;
    if (accuracy >= 80) return AppColors.great;
    if (accuracy >= 70) return AppColors.good;
    if (accuracy >= 60) return AppColors.inaccuracy;
    return AppColors.mistake;
  }
}
