import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class AttemptIndicators extends StatelessWidget {
  final int wrongAttempts;
  final int maxAttempts;

  const AttemptIndicators({
    super.key,
    required this.wrongAttempts,
    required this.maxAttempts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Attempts: ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(width: 8),
          ...List.generate(maxAttempts, (i) {
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < wrongAttempts ? AppColors.error : Colors.grey.withValues(alpha: 0.3),
                border: Border.all(
                  color: i < wrongAttempts ? AppColors.error : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
