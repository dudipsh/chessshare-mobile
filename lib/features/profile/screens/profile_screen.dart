import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/profile_data.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      return _buildUnauthenticated(context, ref);
    }

    final userId = authState.profile!.id;
    final profileState = ref.watch(profileProvider(userId));

    return Scaffold(
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context, ref, authState, profileState),
    );
  }

  Widget _buildUnauthenticated(BuildContext context, WidgetRef ref) {
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

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppAuthState authState,
    ProfileState profileState,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
              onPressed: () => _showSettingsSheet(context, ref),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeader(context, profile, profileState, isDark),
          ),
        ),
      ],
      body: Column(
        children: [
          // Tab bar
          _buildTabBar(context, ref, userId, profileState, isDark),
          // Tab content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(profileProvider(userId).notifier).refresh(),
              child: _buildTabContent(context, ref, userId, profileState, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, profile, ProfileState state, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            isDark ? Colors.grey[900]! : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        _getInitials(profile.fullName ?? 'U'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName ?? 'User',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (profile.email != null)
                      Text(
                        profile.email!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, WidgetRef ref, String userId, ProfileState state, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildTab(context, ref, userId, 0, 'Overview', state.selectedTab),
          _buildTab(context, ref, userId, 1, 'Boards', state.selectedTab),
          _buildTab(context, ref, userId, 2, 'Stats', state.selectedTab),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, WidgetRef ref, String userId, int index, String label, int selected) {
    final isSelected = selected == index;
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

  Widget _buildTabContent(BuildContext context, WidgetRef ref, String userId, ProfileState state, bool isDark) {
    switch (state.selectedTab) {
      case 0:
        return _buildOverview(context, ref, state, isDark);
      case 1:
        return _buildBoards(context, state, isDark);
      case 2:
        return _buildStats(context, state, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverview(BuildContext context, WidgetRef ref, ProfileState state, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Linked accounts
        _buildSection(
          context,
          'Chess Accounts',
          isDark,
          child: Column(
            children: [
              if (state.linkedAccounts.isNotEmpty)
                ...state.linkedAccounts.map((a) => _buildAccountCard(context, a, isDark))
              else
                _buildEmptyAccounts(context, ref, isDark),
            ],
          ),
        ),

        // Quick stats
        const SizedBox(height: 16),
        _buildSection(
          context,
          'Quick Stats',
          isDark,
          child: Row(
            children: [
              _buildStatBox('Boards', '${state.profile?.boardsCount ?? 0}', Icons.dashboard, isDark),
              const SizedBox(width: 12),
              _buildStatBox('Analyzed', '${state.gameReviews.length}', Icons.analytics, isDark),
              const SizedBox(width: 12),
              _buildStatBox('Views', '${state.profile?.totalViews ?? 0}', Icons.visibility, isDark),
            ],
          ),
        ),

        // Bio
        if (state.profile?.bio != null && state.profile!.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection(
            context,
            'About',
            isDark,
            child: Text(state.profile!.bio!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],

        // Bio links
        if (state.bioLinks.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection(
            context,
            'Links',
            isDark,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.bioLinks.map((l) => _buildLinkChip(context, l)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, bool isDark, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, LinkedChessAccount account, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: account.platform == 'chesscom' ? const Color(0xFF769656) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                account.platform == 'chesscom' ? 'C' : 'L',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: account.platform == 'chesscom' ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.displayPlatform, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(account.username, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyAccounts(BuildContext context, WidgetRef ref, bool isDark) {
    return InkWell(
      onTap: () => _editChessUsername(context, ref, 'chesscom'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.add_link, color: Colors.grey[500]),
            const SizedBox(width: 12),
            const Expanded(child: Text('Link your Chess.com or Lichess account')),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkChip(BuildContext context, ProfileBioLink link) {
    return ActionChip(
      avatar: Icon(_getLinkIcon(link.linkType), size: 16),
      label: Text(link.displayName),
      onPressed: () async {
        final uri = Uri.parse(link.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  IconData _getLinkIcon(String type) {
    switch (type) {
      case 'website': return Icons.language;
      case 'youtube': return Icons.play_circle;
      case 'twitter': return Icons.alternate_email;
      case 'twitch': return Icons.videocam;
      default: return Icons.link;
    }
  }

  Widget _buildBoards(BuildContext context, ProfileState state, bool isDark) {
    if (state.isLoadingBoards) return const Center(child: CircularProgressIndicator());

    if (state.boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No boards yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.boards.length,
      itemBuilder: (context, index) {
        final board = state.boards[index];
        return _buildBoardCard(context, board, isDark);
      },
    );
  }

  Widget _buildBoardCard(BuildContext context, UserBoard board, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: board.coverImageUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(board.coverImageUrl!, fit: BoxFit.cover, width: double.infinity),
                    )
                  : const Center(child: Icon(Icons.dashboard, size: 40, color: AppColors.primary)),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  board.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${board.viewsCount}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(width: 8),
                    Icon(board.isPublic ? Icons.public : Icons.lock, size: 14, color: Colors.grey[500]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, ProfileState state, bool isDark) {
    final avgAccuracy = state.averageAccuracy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Game analysis stats
        _buildSection(
          context,
          'Game Analysis',
          isDark,
          child: Column(
            children: [
              Row(
                children: [
                  _buildStatBox('Analyzed', '${state.gameReviews.length}', Icons.analytics, isDark),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    'Avg Accuracy',
                    avgAccuracy != null ? '${avgAccuracy.toStringAsFixed(1)}%' : '-',
                    Icons.track_changes,
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Recent games
        if (state.gameReviews.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection(
            context,
            'Recent Analyzed Games',
            isDark,
            child: Column(
              children: state.gameReviews.take(5).map((r) => _buildGameReviewRow(context, r, isDark)).toList(),
            ),
          ),
        ],

        // Member since
        const SizedBox(height: 16),
        _buildSection(
          context,
          'Account',
          isDark,
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Member since', style: TextStyle(fontSize: 12)),
                  Text(
                    state.profile?.createdAt != null
                        ? '${state.profile!.createdAt.day}/${state.profile!.createdAt.month}/${state.profile!.createdAt.year}'
                        : '-',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameReviewRow(BuildContext context, GameReviewSummary review, bool isDark) {
    final accuracy = review.accuracyWhite ?? review.accuracyBlack ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getAccuracyColor(accuracy).withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                '${accuracy.toInt()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getAccuracyColor(accuracy)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Game ${review.externalGameId.substring(0, 8)}...', style: const TextStyle(fontSize: 13)),
                Text(_formatDate(review.reviewedAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double acc) {
    if (acc >= 90) return AppColors.best;
    if (acc >= 75) return AppColors.good;
    if (acc >= 60) return AppColors.inaccuracy;
    return AppColors.mistake;
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  void _editChessUsername(BuildContext context, WidgetRef ref, String platform) {
    final controller = TextEditingController();
    final profile = ref.read(authProvider).profile;
    controller.text = platform == 'chesscom' ? (profile?.chessComUsername ?? '') : (profile?.lichessUsername ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(platform == 'chesscom' ? 'Chess.com Username' : 'Lichess Username', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter username',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (platform == 'chesscom') {
                        _editChessUsername(context, ref, 'lichess');
                      }
                    },
                    child: Text(platform == 'chesscom' ? 'Lichess instead' : 'Chess.com instead'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final username = controller.text.trim();
                      if (username.isNotEmpty) {
                        if (platform == 'chesscom') {
                          ref.read(authProvider.notifier).updateChessComUsername(username);
                        } else {
                          ref.read(authProvider.notifier).updateLichessUsername(username);
                        }
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.mode == AppThemeMode.dark ||
        (themeState.mode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: isDark,
                onChanged: (v) => ref.read(themeProvider.notifier).setDarkMode(v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(ctx);
                showAboutDialog(context: context, applicationName: 'ChessShare', applicationVersion: '1.0.0');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
