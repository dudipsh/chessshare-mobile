import '../../../core/repositories/profile_repository.dart';
import '../models/profile_data.dart';

// Re-export ProfileStats for convenience
export '../../../core/repositories/profile_repository.dart' show ProfileStats;

/// Service for fetching profile data - delegates to ProfileRepository
/// This service exists for backwards compatibility
class ProfileService {
  /// Get profile by user ID
  static Future<ProfileData?> getProfile(String userId) =>
      ProfileRepository.getProfile(userId);

  /// Get profile bio links
  static Future<List<ProfileBioLink>> getBioLinks(String userId) =>
      ProfileRepository.getBioLinks(userId);

  /// Get linked chess accounts
  static Future<List<LinkedChessAccount>> getLinkedAccounts(String userId) =>
      ProfileRepository.getLinkedAccounts(userId);

  /// Get own boards (uses get_my_boards_paginated RPC)
  static Future<List<UserBoard>> getMyBoards({
    int limit = 20,
    DateTime? cursorPublic,
    DateTime? cursorPrivate,
  }) =>
      ProfileRepository.getMyBoards(
        limit: limit,
        cursorPublic: cursorPublic,
        cursorPrivate: cursorPrivate,
      );

  /// Get another user's public boards
  static Future<List<UserBoard>> getUserBoards(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) =>
      ProfileRepository.getUserBoards(userId, limit: limit, offset: offset);

  /// Get game reviews summary for a user
  static Future<List<GameReviewSummary>> getGameReviews(
    String userId, {
    int limit = 10,
  }) =>
      ProfileRepository.getGameReviews(userId, limit: limit);

  /// Update linked chess account
  static Future<bool> updateLinkedAccount({
    required String platform,
    required String username,
    String? avatarUrl,
  }) =>
      ProfileRepository.updateLinkedAccount(
        platform: platform,
        username: username,
        avatarUrl: avatarUrl,
      );

  /// Update profile bio
  static Future<bool> updateBio(String userId, String bio) =>
      ProfileRepository.updateBio(userId, bio);

  /// Get profile statistics (boards count, views, likes)
  static Future<ProfileStats?> getProfileStats() =>
      ProfileRepository.getProfileStats();
}
