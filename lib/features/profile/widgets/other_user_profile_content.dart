import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../models/profile_data.dart';
import '../providers/profile_provider.dart';

class OtherUserProfileContent extends StatelessWidget {
  final ProfileState profileState;
  final String? userName;
  final String? userAvatar;
  final bool isDark;
  final VoidCallback? onLoadBoards;

  const OtherUserProfileContent({
    super.key,
    required this.profileState,
    required this.userName,
    required this.userAvatar,
    required this.isDark,
    this.onLoadBoards,
  });

  @override
  Widget build(BuildContext context) {
    final profile = profileState.profile;
    final displayName = profile?.fullName ?? userName ?? 'User';
    final avatarUrl = profile?.avatarUrl ?? userAvatar;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(displayName, avatarUrl, profile?.bio),
        const SizedBox(height: 24),
        _buildStatsRow(profile),
        if (profileState.linkedAccounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildChessAccountsSection(),
        ],
        // Show boards section
        const SizedBox(height: 24),
        _buildBoardsSection(context),
      ],
    );
  }

  Widget _buildHeader(String displayName, String? avatarUrl, String? bio) {
    return Center(
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
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(profile) {
    // Calculate stats from boards array (more accurate than profile data)
    final boardsCount = profileState.boards.isNotEmpty
        ? profileState.boards.length
        : (profile?.boardsCount ?? 0);
    final totalViews = profileState.boards.isNotEmpty
        ? profileState.boards.fold(0, (sum, b) => sum + b.viewsCount)
        : (profile?.totalViews ?? 0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Boards', '$boardsCount', Icons.dashboard),
        _buildStatItem('Views', '$totalViews', Icons.visibility),
        _buildStatItem('Followers', '${profile?.followersCount ?? 0}', Icons.people),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildChessAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chess Accounts',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...profileState.linkedAccounts.map(_buildAccountTile),
      ],
    );
  }

  Widget _buildAccountTile(account) {
    final isChessCom = account.platform == 'chesscom';

    return Container(
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
              color: isChessCom ? const Color(0xFF769656) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: !isChessCom ? Border.all(color: Colors.grey[300]!) : null,
            ),
            child: Center(
              child: Text(
                isChessCom ? '♜' : '♞',
                style: TextStyle(fontSize: 18, color: isChessCom ? Colors.white : Colors.black),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.displayPlatform, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                account.username,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Boards',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (profileState.isLoadingBoards)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (profileState.boards.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.dashboard_outlined,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No public boards',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildBoardsGrid(context),
      ],
    );
  }

  Widget _buildBoardsGrid(BuildContext context) {
    // Show up to 4 boards in a 2x2 grid
    final displayBoards = profileState.boards.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayBoards.length,
      itemBuilder: (context, index) => _buildBoardCard(context, displayBoards[index]),
    );
  }

  Widget _buildBoardCard(BuildContext context, UserBoard board) {
    return GestureDetector(
      onTap: () {
        context.pushNamed('study-board', extra: {'boardId': board.id});
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: board.coverImageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          board.coverImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.dashboard, size: 40, color: AppColors.primary),
                      ),
              ),
            ),
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
                      Text(
                        '${board.viewsCount}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.favorite, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${board.likesCount}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
