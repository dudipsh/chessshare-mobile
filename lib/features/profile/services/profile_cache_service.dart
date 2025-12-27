import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile_data.dart';

/// Service for caching profile data locally using SharedPreferences
class ProfileCacheService {
  static const String _profileKey = 'cached_profile';
  static const String _bioLinksKey = 'cached_bio_links';
  static const String _linkedAccountsKey = 'cached_linked_accounts';
  static const String _userBoardsKey = 'cached_user_boards';
  static const String _gameReviewsKey = 'cached_game_reviews';
  static const String _cacheTimestampKey = 'profile_cache_timestamp';

  // Cache duration: 1 hour
  static const Duration cacheDuration = Duration(hours: 1);

  /// Check if the cache is still valid (not expired)
  static Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime) < cacheDuration;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }

  /// Get the cache timestamp
  static Future<DateTime?> getCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      debugPrint('Error getting cache timestamp: $e');
      return null;
    }
  }

  /// Update the cache timestamp to now
  static Future<void> _updateCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error updating cache timestamp: $e');
    }
  }

  // ==================== Profile Data ====================

  /// Cache profile data
  static Future<void> cacheProfile(ProfileData profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profile.toJson());
      await prefs.setString(_profileKey, jsonString);
      await _updateCacheTimestamp();
    } catch (e) {
      debugPrint('Error caching profile: $e');
    }
  }

  /// Get cached profile data
  static Future<ProfileData?> getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileKey);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ProfileData.fromJson(json);
    } catch (e) {
      debugPrint('Error getting cached profile: $e');
      return null;
    }
  }

  // ==================== Bio Links ====================

  /// Cache bio links
  static Future<void> cacheBioLinks(List<ProfileBioLink> links) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = links.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_bioLinksKey, jsonString);
    } catch (e) {
      debugPrint('Error caching bio links: $e');
    }
  }

  /// Get cached bio links
  static Future<List<ProfileBioLink>> getCachedBioLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_bioLinksKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((e) => ProfileBioLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting cached bio links: $e');
      return [];
    }
  }

  // ==================== Linked Accounts ====================

  /// Cache linked chess accounts
  static Future<void> cacheLinkedAccounts(
      List<LinkedChessAccount> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = accounts.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_linkedAccountsKey, jsonString);
    } catch (e) {
      debugPrint('Error caching linked accounts: $e');
    }
  }

  /// Get cached linked chess accounts
  static Future<List<LinkedChessAccount>> getCachedLinkedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_linkedAccountsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((e) => LinkedChessAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting cached linked accounts: $e');
      return [];
    }
  }

  // ==================== User Boards ====================

  /// Cache user boards
  static Future<void> cacheUserBoards(List<UserBoard> boards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = boards.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_userBoardsKey, jsonString);
    } catch (e) {
      debugPrint('Error caching user boards: $e');
    }
  }

  /// Get cached user boards
  static Future<List<UserBoard>> getCachedUserBoards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_userBoardsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((e) => UserBoard.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting cached user boards: $e');
      return [];
    }
  }

  // ==================== Game Reviews ====================

  /// Cache game reviews
  static Future<void> cacheGameReviews(List<GameReviewSummary> reviews) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reviews.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_gameReviewsKey, jsonString);
    } catch (e) {
      debugPrint('Error caching game reviews: $e');
    }
  }

  /// Get cached game reviews
  static Future<List<GameReviewSummary>> getCachedGameReviews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gameReviewsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((e) => GameReviewSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting cached game reviews: $e');
      return [];
    }
  }

  // ==================== Cache Management ====================

  /// Cache all profile data at once
  static Future<void> cacheAllProfileData({
    ProfileData? profile,
    List<ProfileBioLink>? bioLinks,
    List<LinkedChessAccount>? linkedAccounts,
    List<UserBoard>? userBoards,
    List<GameReviewSummary>? gameReviews,
  }) async {
    await Future.wait([
      if (profile != null) cacheProfile(profile),
      if (bioLinks != null) cacheBioLinks(bioLinks),
      if (linkedAccounts != null) cacheLinkedAccounts(linkedAccounts),
      if (userBoards != null) cacheUserBoards(userBoards),
      if (gameReviews != null) cacheGameReviews(gameReviews),
    ]);
  }

  /// Clear all cached profile data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_profileKey),
        prefs.remove(_bioLinksKey),
        prefs.remove(_linkedAccountsKey),
        prefs.remove(_userBoardsKey),
        prefs.remove(_gameReviewsKey),
        prefs.remove(_cacheTimestampKey),
      ]);
    } catch (e) {
      debugPrint('Error clearing profile cache: $e');
    }
  }

  /// Check if any cached data exists
  static Future<bool> hasCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_profileKey) ||
          prefs.containsKey(_bioLinksKey) ||
          prefs.containsKey(_linkedAccountsKey) ||
          prefs.containsKey(_userBoardsKey) ||
          prefs.containsKey(_gameReviewsKey);
    } catch (e) {
      debugPrint('Error checking cached data: $e');
      return false;
    }
  }
}
