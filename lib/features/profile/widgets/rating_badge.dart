import 'package:flutter/material.dart';

class RatingBadge extends StatelessWidget {
  final String label;
  final int rating;
  final Color color;
  final bool isDark;
  final bool isPeak;

  const RatingBadge({
    super.key,
    required this.label,
    required this.rating,
    required this.color,
    required this.isDark,
    this.isPeak = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPeak
            ? Colors.amber.withValues(alpha: 0.15)
            : (isDark ? Colors.grey[800] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(8),
        border: isPeak ? Border.all(color: Colors.amber[300]!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 6),
          if (isPeak)
            const Text('👑 ', style: TextStyle(fontSize: 11)),
          Text(
            rating.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isPeak ? Colors.amber[700] : color,
            ),
          ),
        ],
      ),
    );
  }
}
