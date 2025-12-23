import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../gamification/widgets/level_badge.dart';
import '../../models/profile_data.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/chess_stats_card.dart';
import 'widgets/section_card.dart';
import 'widgets/stat_box.dart';

class OverviewTab extends ConsumerWidget {
  final ProfileState state;
  final bool isDark;
  final VoidCallback onLinkAccount;

  const OverviewTab({
    super.key,
    required this.state,
    required this.isDark,
    required this.onLinkAccount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Gamification stats (Level, Streak, XP)
        const GamificationStatsRow(),
        const SizedBox(height: 16),

        // Quick stats - calculate from boards if API doesn't provide
        SectionCard(
          title: 'Quick Stats',
          isDark: isDark,
          child: Row(
            children: [
              StatBox(
                label: 'Boards',
                value: _getBoardsCount(),
                icon: Icons.dashboard,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              StatBox(label: 'Analyzed', value: '${state.gameReviews.length}', icon: Icons.analytics, isDark: isDark),
              const SizedBox(width: 12),
              StatBox(
                label: 'Views',
                value: _getViewsCount(),
                icon: Icons.visibility,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Linked Chess Accounts with full stats
        const SizedBox(height: 16),
        if (state.linkedAccounts.isNotEmpty) ...[
          ...state.linkedAccounts.map((account) => ChessStatsCard(
            account: account,
            isDark: isDark,
          )),
        ] else ...[
          SectionCard(
            title: 'Chess Accounts',
            isDark: isDark,
            child: _buildEmptyAccounts(context),
          ),
        ],

        // Bio
        if (state.profile?.bio != null && state.profile!.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'About',
            isDark: isDark,
            child: Text(state.profile!.bio!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],

        // Bio links
        if (state.bioLinks.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Links',
            isDark: isDark,
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

  Widget _buildEmptyAccounts(BuildContext context) {
    return InkWell(
      onTap: onLinkAccount,
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

  /// Get boards count - prefer stats RPC, fallback to loaded boards
  String _getBoardsCount() {
    // First try stats from new RPC
    if (state.stats != null) {
      return '${state.stats!.boardsCount}';
    }

    // Fallback to API-provided count in profile
    final apiCount = state.profile?.boardsCount ?? 0;
    if (apiCount > 0) return '$apiCount';

    // Fallback to loaded boards count
    return '${state.boards.length}';
  }

  /// Get views count - prefer stats RPC, fallback to sum from loaded boards
  String _getViewsCount() {
    // First try stats from new RPC
    if (state.stats != null) {
      return '${state.stats!.totalViews}';
    }

    // Fallback to API-provided count in profile
    final apiCount = state.profile?.totalViews ?? 0;
    if (apiCount > 0) return '$apiCount';

    // Fallback to sum from loaded boards
    if (state.boards.isNotEmpty) {
      final sum = state.boards.fold(0, (sum, b) => sum + b.viewsCount);
      return '$sum';
    }

    return '0';
  }
}
