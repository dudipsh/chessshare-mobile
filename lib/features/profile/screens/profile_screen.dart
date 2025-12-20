import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'profile/link_account_sheet.dart';
import 'profile/overview_tab.dart';
import 'profile/profile_header.dart';
import 'profile/settings_sheet.dart';
import 'profile/stats_tab.dart';

class ProfileScreen extends ConsumerWidget {
  /// Optional: View another user's profile instead of the authenticated user
  final String? viewUserId;
  final String? viewUserName;
  final String? viewUserAvatar;

  const ProfileScreen({
    super.key,
    this.viewUserId,
    this.viewUserName,
    this.viewUserAvatar,
  });

  /// Check if viewing another user's profile
  bool get isViewingOtherUser => viewUserId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Viewing another user's profile
    if (isViewingOtherUser) {
      final profileState = ref.watch(profileProvider(viewUserId!));
      return Scaffold(
        appBar: AppBar(
          title: Text(viewUserName ?? 'Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: profileState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _OtherUserProfileContent(
                profileState: profileState,
                userName: viewUserName,
                userAvatar: viewUserAvatar,
                isDark: isDark,
              ),
      );
    }

    // Viewing own profile - need to be authenticated
    if (!authState.isAuthenticated) {
      return _UnauthenticatedView();
    }

    final userId = authState.profile!.id;
    final profileState = ref.watch(profileProvider(userId));

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
          _Tab(label: 'Stats', index: 1, selectedTab: selectedTab, userId: userId),
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

/// Content for viewing another user's profile
class _OtherUserProfileContent extends StatelessWidget {
  final ProfileState profileState;
  final String? userName;
  final String? userAvatar;
  final bool isDark;

  const _OtherUserProfileContent({
    required this.profileState,
    required this.userName,
    required this.userAvatar,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final profile = profileState.profile;
    final displayName = profile?.fullName ?? userName ?? 'User';
    final avatarUrl = profile?.avatarUrl ?? userAvatar;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, size: 50, color: isDark ? Colors.grey[500] : Colors.grey[600])
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    profile.bio!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(
              label: 'Boards',
              value: '${profile?.boardsCount ?? 0}',
              icon: Icons.dashboard,
              isDark: isDark,
            ),
            _StatItem(
              label: 'Views',
              value: '${profile?.totalViews ?? 0}',
              icon: Icons.visibility,
              isDark: isDark,
            ),
            _StatItem(
              label: 'Followers',
              value: '${profile?.followersCount ?? 0}',
              icon: Icons.people,
              isDark: isDark,
            ),
          ],
        ),

        // Chess accounts (if linked)
        if (profileState.linkedAccounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Chess Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...profileState.linkedAccounts.map((account) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: account.platform == 'chesscom' ? const Color(0xFF769656) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: account.platform == 'lichess' ? Border.all(color: Colors.grey[300]!) : null,
                  ),
                  child: Center(
                    child: Text(
                      account.platform == 'chesscom' ? '♜' : '♞',
                      style: TextStyle(
                        fontSize: 18,
                        color: account.platform == 'chesscom' ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayPlatform,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      account.username,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
