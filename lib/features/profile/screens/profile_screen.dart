import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'profile/boards_tab.dart';
import 'profile/link_account_sheet.dart';
import 'profile/overview_tab.dart';
import 'profile/profile_header.dart';
import 'profile/settings_sheet.dart';
import 'profile/stats_tab.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      return _UnauthenticatedView();
    }

    final userId = authState.profile!.id;
    final profileState = ref.watch(profileProvider(userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ProfileContent(
              authState: authState,
              profileState: profileState,
              isDark: isDark,
            ),
    );
  }
}

class _UnauthenticatedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Sign in to view your profile', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sync your games, puzzles, and stats',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.pushNamed('login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final AppAuthState authState;
  final ProfileState profileState;
  final bool isDark;

  const _ProfileContent({
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
          _TabBar(
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
        return BoardsTab(
          boards: profileState.boards,
          isLoading: profileState.isLoadingBoards,
          isDark: isDark,
        );
      case 2:
        return StatsTab(state: profileState, isDark: isDark);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TabBar extends ConsumerWidget {
  final String userId;
  final int selectedTab;
  final bool isDark;

  const _TabBar({
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
          _Tab(label: 'Overview', index: 0, selectedTab: selectedTab, userId: userId),
          _Tab(label: 'Boards', index: 1, selectedTab: selectedTab, userId: userId),
          _Tab(label: 'Stats', index: 2, selectedTab: selectedTab, userId: userId),
        ],
      ),
    );
  }
}

class _Tab extends ConsumerWidget {
  final String label;
  final int index;
  final int selectedTab;
  final String userId;

  const _Tab({
    required this.label,
    required this.index,
    required this.selectedTab,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
