import '../../features/profile/models/profile_data.dart';
import 'base_repository.dart';

/// Repository for profile-related data
class ProfileRepository {
  /// Get profile by user ID
  static Future<ProfileData?> getProfile(String userId) async {
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

  /// Get user boards
  static Future<List<UserBoard>> getUserBoards(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // Try RPC first
    final rpcResult = await BaseRepository.executeRpc<List<UserBoard>>(
      functionName: 'get_user_boards_with_author',
      params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_offset': offset,
      },
      parser: (response) {
        if (response == null) return <UserBoard>[];
        final list = response as List;
        return list
            .map((e) => UserBoard.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      defaultValue: null, // Use null to detect failure
    );

    // If RPC worked, return the result
    if (rpcResult.success && rpcResult.data != null) {
      return rpcResult.data!;
    }

    // Fallback: Query boards table directly
    final directResult = await BaseRepository.executeAuth<List<UserBoard>>(
      operation: 'getUserBoards',
      query: (client) async {
        final response = await client
            .from('boards')
            .select('id, title, cover_image_url, is_public, views_count, likes_count, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        final list = response as List;
        if (list.isEmpty) return <UserBoard>[];
        return list.map((e) {
          // Map the table columns to UserBoard model
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

    return directResult.data ?? [];
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
