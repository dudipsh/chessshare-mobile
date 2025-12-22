import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/colors.dart';
import '../../../core/api/chess_com_api.dart';
import '../../../core/api/lichess_api.dart';
import '../models/profile_data.dart';
import 'rating_badge.dart';
import 'stat_box.dart';

class _ChessAccountStatsInternal {
  final String platform;
  final String username;
  final String? avatarUrl;
  final String? title;
  final int? bulletRating;
  final int? blitzRating;
  final int? rapidRating;
  final int? classicalRating;
  final int? puzzleRating;
  final int? bulletPeak;
  final int? blitzPeak;
  final int? rapidPeak;
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;

  _ChessAccountStatsInternal({
    required this.platform,
    required this.username,
    this.avatarUrl,
    this.title,
    this.bulletRating,
    this.blitzRating,
    this.rapidRating,
    this.classicalRating,
    this.puzzleRating,
    this.bulletPeak,
    this.blitzPeak,
    this.rapidPeak,
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  double get winRate => totalGames > 0 ? (wins / totalGames * 100) : 0;

  String get profileUrl => platform == 'chesscom'
      ? 'https://www.chess.com/member/$username'
      : 'https://lichess.org/@/$username';
}

class ChessStatsCard extends StatefulWidget {
  final LinkedChessAccount account;
  final bool isDark;

  const ChessStatsCard({
    super.key,
    required this.account,
    required this.isDark,
  });

  @override
  State<ChessStatsCard> createState() => _ChessStatsCardState();
}

class _ChessStatsCardState extends State<ChessStatsCard> {
  _ChessAccountStatsInternal? _stats;
  bool _isLoading = true;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      if (widget.account.platform == 'chesscom') {
        await _loadChessComStats();
      } else {
        await _loadLichessStats();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChessComStats() async {
    final profile = await ChessComApi.getProfile(widget.account.username);
    final stats = await ChessComApi.getStats(widget.account.username);

    if (stats == null) return;

    final bullet = stats['chess_bullet'] as Map<String, dynamic>?;
    final blitz = stats['chess_blitz'] as Map<String, dynamic>?;
    final rapid = stats['chess_rapid'] as Map<String, dynamic>?;
    final tactics = stats['tactics'] as Map<String, dynamic>?;

    int totalGames = 0, wins = 0, losses = 0, draws = 0;

    for (final mode in [bullet, blitz, rapid]) {
      if (mode != null) {
        final record = mode['record'] as Map<String, dynamic>?;
        if (record != null) {
          wins += (record['win'] as int?) ?? 0;
          losses += (record['loss'] as int?) ?? 0;
          draws += (record['draw'] as int?) ?? 0;
        }
      }
    }
    totalGames = wins + losses + draws;

    _stats = _ChessAccountStatsInternal(
      platform: 'chesscom',
      username: widget.account.username,
      avatarUrl: profile?['avatar'] as String?,
      title: profile?['title'] as String?,
      bulletRating: (bullet?['last'] as Map<String, dynamic>?)?['rating'] as int?,
      blitzRating: (blitz?['last'] as Map<String, dynamic>?)?['rating'] as int?,
      rapidRating: (rapid?['last'] as Map<String, dynamic>?)?['rating'] as int?,
      puzzleRating: (tactics?['highest'] as Map<String, dynamic>?)?['rating'] as int?,
      bulletPeak: (bullet?['best'] as Map<String, dynamic>?)?['rating'] as int?,
      blitzPeak: (blitz?['best'] as Map<String, dynamic>?)?['rating'] as int?,
      rapidPeak: (rapid?['best'] as Map<String, dynamic>?)?['rating'] as int?,
      totalGames: totalGames,
      wins: wins,
      losses: losses,
      draws: draws,
    );
  }

  Future<void> _loadLichessStats() async {
    final profile = await LichessApi.getProfile(widget.account.username);
    if (profile == null) return;

    final perfs = profile['perfs'] as Map<String, dynamic>?;
    final count = profile['count'] as Map<String, dynamic>?;

    _stats = _ChessAccountStatsInternal(
      platform: 'lichess',
      username: widget.account.username,
      title: profile['title'] as String?,
      bulletRating: (perfs?['bullet'] as Map<String, dynamic>?)?['rating'] as int?,
      blitzRating: (perfs?['blitz'] as Map<String, dynamic>?)?['rating'] as int?,
      rapidRating: (perfs?['rapid'] as Map<String, dynamic>?)?['rating'] as int?,
      classicalRating: (perfs?['classical'] as Map<String, dynamic>?)?['rating'] as int?,
      puzzleRating: (perfs?['puzzle'] as Map<String, dynamic>?)?['rating'] as int?,
      totalGames: (count?['all'] as int?) ?? 0,
      wins: (count?['win'] as int?) ?? 0,
      losses: (count?['loss'] as int?) ?? 0,
      draws: (count?['draw'] as int?) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChessCom = widget.account.platform == 'chesscom';
    final platformColor = isChessCom ? const Color(0xFF769656) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(isChessCom, platformColor),
          if (_isExpanded) ...[
            if (_isLoading)
              const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2))
            else if (_stats != null) ...[
              _buildRatingsSection(),
              _buildStatisticsSection(),
              if (_stats!.bulletPeak != null || _stats!.blitzPeak != null || _stats!.rapidPeak != null)
                _buildPeakRatingsSection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isChessCom, Color platformColor) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: platformColor,
                borderRadius: BorderRadius.circular(10),
                border: isChessCom ? null : Border.all(color: Colors.grey[300]!),
              ),
              child: _stats?.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _stats!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlatformIcon(isChessCom),
                      ),
                    )
                  : _buildPlatformIcon(isChessCom),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_stats?.title != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _stats!.title!,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          widget.account.username,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.account.displayPlatform,
                    style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.open_in_new, size: 18, color: widget.isDark ? Colors.grey[400] : Colors.grey[500]),
              onPressed: () async {
                final url = _stats?.profileUrl ??
                    (isChessCom
                        ? 'https://www.chess.com/member/${widget.account.username}'
                        : 'https://lichess.org/@/${widget.account.username}');
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: widget.isDark ? Colors.grey[400] : Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(bool isChessCom) {
    return Center(
      child: Text(
        isChessCom ? '♜' : '♞',
        style: TextStyle(fontSize: 22, color: isChessCom ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildRatingsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
              const SizedBox(width: 6),
              Text('Ratings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_stats!.bulletRating != null) RatingBadge(label: 'Bullet', rating: _stats!.bulletRating!, color: Colors.red[400]!, isDark: widget.isDark),
              if (_stats!.blitzRating != null) RatingBadge(label: 'Blitz', rating: _stats!.blitzRating!, color: Colors.amber[600]!, isDark: widget.isDark),
              if (_stats!.rapidRating != null) RatingBadge(label: 'Rapid', rating: _stats!.rapidRating!, color: AppColors.primary, isDark: widget.isDark),
              if (_stats!.classicalRating != null) RatingBadge(label: 'Classical', rating: _stats!.classicalRating!, color: Colors.blue[400]!, isDark: widget.isDark),
              if (_stats!.puzzleRating != null) RatingBadge(label: 'Puzzle', rating: _stats!.puzzleRating!, color: Colors.purple[400]!, isDark: widget.isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: 16, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
              const SizedBox(width: 6),
              Text('Statistics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Win Rate', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
              const Spacer(),
              Text('${_stats!.winRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _stats!.winRate / 100,
              backgroundColor: widget.isDark ? Colors.grey[700] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatBox(label: 'Wins', value: _stats!.wins, color: AppColors.win, isDark: widget.isDark),
              const SizedBox(width: 8),
              StatBox(label: 'Draws', value: _stats!.draws, color: Colors.grey, isDark: widget.isDark),
              const SizedBox(width: 8),
              StatBox(label: 'Losses', value: _stats!.losses, color: AppColors.loss, isDark: widget.isDark),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!))),
            child: Row(
              children: [
                Icon(Icons.sports_esports, size: 16, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text('Total Games', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                const Spacer(),
                Text(_formatNumber(_stats!.totalGames), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakRatingsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: 16, color: Colors.amber[600]),
              const SizedBox(width: 6),
              Text('Peak Ratings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_stats!.bulletPeak != null) RatingBadge(label: 'Bullet', rating: _stats!.bulletPeak!, color: Colors.amber[600]!, isDark: widget.isDark, isPeak: true),
              if (_stats!.blitzPeak != null) RatingBadge(label: 'Blitz', rating: _stats!.blitzPeak!, color: Colors.amber[600]!, isDark: widget.isDark, isPeak: true),
              if (_stats!.rapidPeak != null) RatingBadge(label: 'Rapid', rating: _stats!.rapidPeak!, color: Colors.amber[600]!, isDark: widget.isDark, isPeak: true),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }
}
