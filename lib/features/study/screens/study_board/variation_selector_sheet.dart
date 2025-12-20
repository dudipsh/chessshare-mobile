import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../models/study_board.dart';

void showVariationSelectorSheet({
  required BuildContext context,
  required List<StudyVariation> variations,
  required int currentIndex,
  required bool isDark,
  required ValueChanged<int> onSelect,
}) {
  if (variations.isEmpty) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select Variation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: variations.length,
                itemBuilder: (context, index) {
                  final variation = variations[index];
                  final isSelected = index == currentIndex;

                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: variation.isCompleted
                            ? AppColors.success
                            : (isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade200)),
                      ),
                      child: Center(
                        child: variation.isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      variation.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: variation.completionPercentage > 0
                        ? Text(
                            '${variation.completionPercentage.toInt()}% completed',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                          )
                        : null,
                    trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(index);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
