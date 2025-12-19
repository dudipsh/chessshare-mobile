import 'package:flutter/foundation.dart';

import '../../../core/api/supabase_service.dart';
import '../models/profile_data.dart';

/// Service for fetching profile data from Supabase
class ProfileService {
  /// Get profile by user ID
  static Future<ProfileData?> getProfile(String userId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_profile_by_id',
        params: {'profile_id': userId},
      );

      if (response == null) return null;

      // Handle if response is a list (some RPCs return lists)
      final data = response is List ? response.first : response;
      return ProfileData.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Get profile bio links
  static Future<List<ProfileBioLink>> getBioLinks(String userId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_profile_bio_links',
        params: {'profile_id': userId},
      );

      if (response == null) return [];

      final list = response as List;
      return list
          .map((e) => ProfileBioLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching bio links: $e');
      return [];
    }
  }

  /// Get linked chess accounts
  static Future<List<LinkedChessAccount>> getLinkedAccounts(String userId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_linked_chess_accounts',
        params: {'p_user_id': userId},
      );

      if (response == null) return [];

      final list = response as List;
      return list
          .map((e) => LinkedChessAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching linked accounts: $e');
      return [];
    }
  }

  /// Get user boards
  static Future<List<UserBoard>> getUserBoards(String userId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_user_boards_with_author',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response == null) return [];

      final list = response as List;
      return list
          .map((e) => UserBoard.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user boards: $e');
      return [];
    }
  }

  /// Get game reviews summary for a user
  static Future<List<GameReviewSummary>> getGameReviews(String userId, {int limit = 10}) async {
    try {
      final response = await SupabaseService.client
          .from('game_reviews')
          .select('id,external_game_id,accuracy_white,accuracy_black,reviewed_at,personal_mistakes(count)')
          .eq('user_id', userId)
          .order('reviewed_at', ascending: false)
          .limit(limit);

      final list = response as List;
      if (list.isEmpty) return [];
      return list
          .map((e) => GameReviewSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching game reviews: $e');
      return [];
    }
  }

  /// Update linked chess account
  static Future<bool> updateLinkedAccount({
    required String platform,
    required String username,
    String? avatarUrl,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'upsert_linked_chess_account',
        params: {
          'p_platform': platform,
          'p_username': username,
          'p_linked_at': DateTime.now().toUtc().toIso8601String(),
          'p_avatar_url': avatarUrl,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error updating linked account: $e');
      return false;
    }
  }

  /// Update profile bio
  static Future<bool> updateBio(String userId, String bio) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'bio': bio})
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error updating bio: $e');
      return false;
    }
  }
}
