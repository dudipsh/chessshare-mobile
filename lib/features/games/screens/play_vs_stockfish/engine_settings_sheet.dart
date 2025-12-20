import 'package:flutter/material.dart';

Future<int?> showEngineSettingsSheet({
  required BuildContext context,
  required int currentLevel,
}) async {
  int selectedLevel = currentLevel;

  return showModalBottomSheet<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Engine Level',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Level $selectedLevel',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Slider(
              value: selectedLevel.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: 'Level $selectedLevel',
              onChanged: (value) {
                setSheetState(() {
                  selectedLevel = value.round();
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Beginner', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('Master', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedLevel),
                child: const Text('Apply'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    ),
  );
}
