import 'package:flutter/foundation.dart';

import '../../features/profile/models/profile_data.dart';
import 'base_repository.dart';

/// Profile statistics returned by get_my_profile_stats RPC
class ProfileStats {
  final int boardsCount;
  final int publicBoardsCount;
  final int privateBoardsCount;
  final int totalViews;
  final int totalLikes;

  ProfileStats({
    required this.boardsCount,
    required this.publicBoardsCount,
    required this.privateBoardsCount,
    required this.totalViews,
    required this.totalLikes,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      boardsCount: (json['boards_count'] as num?)?.toInt() ?? 0,
      publicBoardsCount: (json['public_boards_count'] as num?)?.toInt() ?? 0,
      privateBoardsCount: (json['private_boards_count'] as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      totalLikes: (json['total_likes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Repository for profile-related data
class ProfileRepository {
  /// Get profile by user ID - uses get_user_dashboard_data for comprehensive stats
  static Future<ProfileData?> getProfile(String userId) async {
    // Try get_user_dashboard_data first (returns boards_count, total_views, etc.)
    final dashboardResult = await BaseRepository.executeRpc<ProfileData?>(
      functionName: 'get_user_dashboard_data',
      params: {'target_user_id': userId},
      parser: (response) {
        if (response == null) return null;
        final data = response is List ? response.first : response;
        return ProfileData.fromJson(data as Map<String, dynamic>);
      },
      defaultValue: null,
    );

    if (dashboardResult.success && dashboardResult.data != null) {
      return dashboardResult.data;
    }

    // Fallback to get_profile_by_id if dashboard RPC fails
    final result = await BaseRepository.executeRpc<ProfileData?>(
      functionName: 'get_profile_by_id',
      params: {'profile_id': userId},
      parser: (response) {
        if (response == null) return null;
        final data = response is List ? response.first : response;
        return ProfileData.fromJson(data as Map<String, dynamic>);
      },
      defaultValue: null,
    );
    return result.data;
  }

  /// Get profile bio links
  static Future<List<ProfileBioLink>> getBioLinks(String userId) async {
    final result = await BaseRepository.executeRpc<List<ProfileBioLink>>(
      functionName: 'get_profile_bio_links',
      params: {'profile_id': userId},
      parser: (response) {
        if (response == null) return <ProfileBioLink>[];
        final list = response as List;
        return list
            .map((e) => ProfileBioLink.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      defaultValue: <ProfileBioLink>[],
    );
    return result.data ?? [];
  }

  /// Get linked chess accounts
  /// Note: The RPC function uses auth.uid() internally, no user_id parameter needed
  static Future<List<LinkedChessAccount>> getLinkedAccounts(String userId) async {
    final result = await BaseRepository.executeRpc<List<LinkedChessAccount>>(
      functionName: 'get_linked_chess_accounts',
      params: {}, // Web project calls this without parameters - it uses auth.uid() internally
      parser: (response) {
        if (response == null) return <LinkedChessAccount>[];
        final list = response as List;
        return list
            .map((e) => LinkedChessAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      defaultValue: <LinkedChessAccount>[],
    );
    return result.data ?? [];
  }

  /// Get own boards - uses get_my_boards_paginated RPC
  /// Note: The RPC requires p_is_public to be true or false (not null)
  /// So we fetch public and private boards separately and combine them
  static Future<List<UserBoard>> getMyBoards({
    int limit = 20,
    DateTime? cursorPublic,
    DateTime? cursorPrivate,
  }) async {
    // Fetch public and private boards in parallel
    final results = await Future.wait([
      _fetchMyBoardsByVisibility(isPublic: true, limit: limit, cursor: cursorPublic),
      _fetchMyBoardsByVisibility(isPublic: false, limit: limit, cursor: cursorPrivate),
    ]);

    final publicBoards = results[0];
    final privateBoards = results[1];

    // Combine and sort by created_at descending
    final allBoards = [...publicBoards, ...privateBoards];
    allBoards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    debugPrint('getMyBoards: Combined ${publicBoards.length} public + ${privateBoards.length} private = ${allBoards.length} total boards');

    return allBoards.take(limit).toList();
  }

  static Future<List<UserBoard>> _fetchMyBoardsByVisibility({
    required bool isPublic,
    required int limit,
    DateTime? cursor,
  }) async {
    final rpcResult = await BaseRepository.executeRpc<List<UserBoard>>(
      functionName: 'get_my_boards_paginated',
      params: {
        'p_is_public': isPublic,
        'p_limit': limit,
        'p_cursor_created_at': cursor?.toUtc().toIso8601String(),
      },
      parser: (response) {
        if (response == null) return <UserBoard>[];
        final list = response as List;
        debugPrint('get_my_boards_paginated (isPublic=$isPublic, cursor=$cursor) returned ${list.length} boards');
        return list.map((e) {
          final map = e as Map<String, dynamic>;
          return UserBoard(
            id: map['id'] as String,
            title: map['title'] as String? ?? 'Untitled Board',
            coverImageUrl: map['cover_image_url'] as String?,
            isPublic: map['is_public'] as bool? ?? true,
            viewsCount: map['views_count'] as int? ?? 0,
            likesCount: map['likes_count'] as int? ?? 0,
            createdAt: DateTime.parse(map['created_at'] as String),
            authorName: map['author_name'] as String?,
            authorAvatarUrl: map['author_avatar_url'] as String?,
          );
        }).toList();
      },
      defaultValue: <UserBoard>[],
    );

    return rpcResult.data ?? [];
  }

  /// Get another user's public boards - uses direct query
  static Future<List<UserBoard>> getUserBoards(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // Query boards table directly for other users (only public boards)
    final result = await BaseRepository.executeAuth<List<UserBoard>>(
      operation: 'getUserBoards',
      query: (client) async {
        final response = await client
            .from('boards')
            .select('id, title, cover_image_url, is_public, views_count, likes_count, created_at')
            .eq('user_id', userId)
            .eq('is_public', true) // Only public boards for other users
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        final list = response as List;
        debugPrint('getUserBoards: Direct query returned ${list.length} boards for user $userId');
        if (list.isEmpty) return <UserBoard>[];
        return list.map((e) {
          return UserBoard(
            id: e['id'] as String,
            title: e['title'] as String? ?? 'Untitled Board',
            coverImageUrl: e['cover_image_url'] as String?,
            isPublic: e['is_public'] as bool? ?? true,
            viewsCount: e['views_count'] as int? ?? 0,
            likesCount: e['likes_count'] as int? ?? 0,
            createdAt: DateTime.parse(e['created_at'] as String),
          );
        }).toList();
      },
      defaultValue: <UserBoard>[],
    );

    return result.data ?? [];
  }

  /// Get game reviews summary
  static Future<List<GameReviewSummary>> getGameReviews(
    String userId, {
    int limit = 10,
  }) async {
    final result = await BaseRepository.executeAuth<List<GameReviewSummary>>(
      operation: 'getGameReviews',
      query: (client) async {
        final response = await client
            .from('game_reviews')
            .select('id,external_game_id,accuracy_white,accuracy_black,reviewed_at,personal_mistakes(count)')
            .eq('user_id', userId)
            .order('reviewed_at', ascending: false)
            .limit(limit);

        final list = response as List;
        if (list.isEmpty) return <GameReviewSummary>[];
        return list
            .map((e) => GameReviewSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      defaultValue: <GameReviewSummary>[],
    );
    return result.data ?? [];
  }

  /// Get profile statistics (boards count, views, likes) using RPC
  static Future<ProfileStats?> getProfileStats() async {
    final result = await BaseRepository.executeRpc<ProfileStats?>(
      functionName: 'get_my_profile_stats',
      params: {},
      parser: (response) {
        if (response == null) return null;
        final data = response is List ? response.first : response;
        debugPrint('ProfileStats response: $data');
        return ProfileStats.fromJson(data as Map<String, dynamic>);
      },
      defaultValue: null,
    );
    return result.data;
  }

  /// Update linked chess account
  static Future<bool> updateLinkedAccount({
    required String platform,
    required String username,
    String? avatarUrl,
  }) async {
    final result = await BaseRepository.executeRpc<bool>(
      functionName: 'upsert_linked_chess_account',
      params: {
        'p_platform': platform,
        'p_username': username,
        'p_linked_at': DateTime.now().toUtc().toIso8601String(),
        'p_avatar_url': avatarUrl,
      },
      parser: (_) => true,
      defaultValue: false,
    );
    return result.success;
  }

  /// Update profile bio
  static Future<bool> updateBio(String userId, String bio) async {
    final result = await BaseRepository.executeAuth<bool>(
      operation: 'updateBio',
      query: (client) async {
        await client.from('profiles').update({'bio': bio}).eq('id', userId);
        return true;
      },
      defaultValue: false,
    );
    return result.data ?? false;
  }
}
