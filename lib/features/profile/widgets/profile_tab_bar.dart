import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../providers/profile_provider.dart';

class ProfileTabBar extends ConsumerWidget {
  final String userId;
  final int selectedTab;
  final bool isDark;

  const ProfileTabBar({
    super.key,
    required this.userId,
    required this.selectedTab,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildTab(ref, 'Overview', 0),
          _buildTab(ref, 'Stats', 1),
          _buildTab(ref, 'My Plan', 2),
        ],
      ),
    );
  }

  Widget _buildTab(WidgetRef ref, String label, int index) {
    final isSelected = selectedTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(profileProvider(userId).notifier).selectTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : null,
            ),
          ),
        ),
      ),
    );
  }
}
