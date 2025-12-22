import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../providers/profile_provider.dart';

class OtherUserProfileContent extends StatelessWidget {
  final ProfileState profileState;
  final String? userName;
  final String? userAvatar;
  final bool isDark;

  const OtherUserProfileContent({
    super.key,
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
        _buildHeader(displayName, avatarUrl, profile?.bio),
        const SizedBox(height: 24),
        _buildStatsRow(profile),
        if (profileState.linkedAccounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildChessAccountsSection(),
        ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Boards', '${profile?.boardsCount ?? 0}', Icons.dashboard),
        _buildStatItem('Views', '${profile?.totalViews ?? 0}', Icons.visibility),
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
}
