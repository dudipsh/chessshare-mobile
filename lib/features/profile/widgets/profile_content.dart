import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/profile/link_account_sheet.dart';
import '../screens/profile/overview_tab.dart';
import '../screens/profile/profile_header.dart';
import '../screens/profile/settings_sheet.dart';
import '../screens/profile/stats_tab.dart';
import 'profile_tab_bar.dart';

class ProfileContent extends ConsumerWidget {
  final AppAuthState authState;
  final ProfileState profileState;
  final bool isDark;

  const ProfileContent({
    super.key,
    required this.authState,
    required this.profileState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = authState.profile!;
    final userId = profile.id;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showProfileSettingsSheet(context, ref),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: ProfileHeader(
              avatarUrl: profile.avatarUrl,
              fullName: profile.fullName,
              email: profile.email,
              isDark: isDark,
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          ProfileTabBar(
            userId: userId,
            selectedTab: profileState.selectedTab,
            isDark: isDark,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(profileProvider(userId).notifier).refresh(),
              child: _buildTabContent(context, ref, userId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, WidgetRef ref, String userId) {
    switch (profileState.selectedTab) {
      case 0:
        return OverviewTab(
          state: profileState,
          isDark: isDark,
          onLinkAccount: () => showLinkAccountSheet(context, ref),
        );
      case 1:
        return StatsTab(state: profileState, isDark: isDark);
      default:
        return const SizedBox.shrink();
    }
  }
}
