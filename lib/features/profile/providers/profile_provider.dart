import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/local_database.dart';
import '../models/profile_data.dart';
import '../services/profile_cache_service.dart';
import '../services/profile_service.dart';

/// State for the profile feature
class ProfileState {
  final ProfileData? profile;
  final ProfileStats? stats; // Boards count, views, likes from RPC
  final List<ProfileBioLink> bioLinks;
  final List<LinkedChessAccount> linkedAccounts;
  final List<UserBoard> boards;
  final List<GameReviewSummary> gameReviews;
  final bool isLoading;
  final bool isLoadingBoards;
  final bool isLoadingMoreBoards; // Loading more boards (pagination)
  final bool hasMoreBoards; // Has more boards to load
  final bool isRefreshing; // Loading fresh data while showing cached
  final bool isFromCache; // Data is from cache (may be stale)
  final String? error;
  final int selectedTab; // 0: Overview, 1: Boards, 2: Stats

  const ProfileState({
    this.profile,
    this.stats,
    this.bioLinks = const [],
    this.linkedAccounts = const [],
    this.boards = const [],
    this.gameReviews = const [],
    this.isLoading = false,
    this.isLoadingBoards = false,
    this.isLoadingMoreBoards = false,
    this.hasMoreBoards = true,
    this.isRefreshing = false,
    this.isFromCache = false,
    this.error,
    this.selectedTab = 0,
  });

  ProfileState copyWith({
    ProfileData? profile,
    ProfileStats? stats,
    List<ProfileBioLink>? bioLinks,
    List<LinkedChessAccount>? linkedAccounts,
    List<UserBoard>? boards,
    List<GameReviewSummary>? gameReviews,
    bool? isLoading,
    bool? isLoadingBoards,
    bool? isLoadingMoreBoards,
    bool? hasMoreBoards,
    bool? isRefreshing,
    bool? isFromCache,
    String? error,
    int? selectedTab,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      bioLinks: bioLinks ?? this.bioLinks,
      linkedAccounts: linkedAccounts ?? this.linkedAccounts,
      boards: boards ?? this.boards,
      gameReviews: gameReviews ?? this.gameReviews,
      isLoading: isLoading ?? this.isLoading,
      isLoadingBoards: isLoadingBoards ?? this.isLoadingBoards,
      isLoadingMoreBoards: isLoadingMoreBoards ?? this.isLoadingMoreBoards,
      hasMoreBoards: hasMoreBoards ?? this.hasMoreBoards,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isFromCache: isFromCache ?? this.isFromCache,
      error: clearError ? null : (error ?? this.error),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }

  /// Get Chess.com account if linked
  LinkedChessAccount? get chessComAccount {
    try {
      return linkedAccounts.firstWhere((a) => a.platform == 'chesscom');
    } catch (_) {
      return null;
    }
  }

  /// Get Lichess account if linked
  LinkedChessAccount? get lichessAccount {
    try {
      return linkedAccounts.firstWhere((a) => a.platform == 'lichess');
    } catch (_) {
      return null;
    }
  }

  /// Get average accuracy from game reviews
  double? get averageAccuracy {
    if (gameReviews.isEmpty) return null;

    double total = 0;
    int count = 0;

    for (final review in gameReviews) {
      if (review.accuracyWhite != null) {
        total += review.accuracyWhite!;
        count++;
      }
      if (review.accuracyBlack != null) {
        total += review.accuracyBlack!;
        count++;
      }
    }

    return count > 0 ? total / count : null;
  }
}

/// Notifier for profile state
class ProfileNotifier extends StateNotifier<ProfileState> {
  final String userId;

  /// Check if viewing own profile vs another user's profile
  bool get isOwnProfile {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && currentUserId == userId;
  }

  ProfileNotifier(this.userId) : super(const ProfileState(isLoading: true)) {
    _initProfile();
  }

  /// Initialize profile - load from cache first, then fetch fresh data
  Future<void> _initProfile() async {
    // Only use cache for own profile - other users should always fetch fresh
    if (isOwnProfile) {
      final hasCachedData = await _loadFromCache();

      if (hasCachedData) {
        // Have cached data - show it immediately and refresh in background
        state = state.copyWith(isRefreshing: true);
        await _fetchFreshData();
        state = state.copyWith(isRefreshing: false);
        return;
      }
    }

    // No cached data or viewing other user - fetch from network
    await loadProfile();
  }

  /// Load profile data from cache
  Future<bool> _loadFromCache() async {
    try {
      // Load cached data
      final results = await Future.wait([
        ProfileCacheService.getCachedProfile(),
        ProfileCacheService.getCachedBioLinks(),
        ProfileCacheService.getCachedLinkedAccounts(),
        ProfileCacheService.getCachedGameReviews(),
        ProfileCacheService.getCachedUserBoards(),
      ]);

      final cachedProfile = results[0] as ProfileData?;
      final cachedBioLinks = results[1] as List<ProfileBioLink>;
      final cachedLinkedAccounts = results[2] as List<LinkedChessAccount>;
      final cachedGameReviews = results[3] as List<GameReviewSummary>;
      final cachedBoards = results[4] as List<UserBoard>;

      if (cachedProfile != null) {
        state = state.copyWith(
          profile: cachedProfile,
          bioLinks: cachedBioLinks,
          linkedAccounts: cachedLinkedAccounts,
          gameReviews: cachedGameReviews,
          boards: cachedBoards,
          isLoading: false,
          isFromCache: true,
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      return false;
    }
  }

  /// Fetch fresh data from network and update cache
  Future<void> _fetchFreshData() async {
    try {
      ProfileData? profile;
      List<ProfileBioLink> bioLinks = [];
      List<LinkedChessAccount> linkedAccounts = [];
      List<GameReviewSummary> gameReviews = [];
      ProfileStats? stats;

      if (isOwnProfile) {
        // Own profile - fetch all data including linked accounts and stats
        final results = await Future.wait([
          ProfileService.getProfile(userId),
          ProfileService.getBioLinks(userId),
          ProfileService.getLinkedAccounts(userId),
          ProfileService.getGameReviews(userId),
          ProfileService.getProfileStats(), // Only for own profile
        ]);

        profile = results[0] as ProfileData?;
        bioLinks = results[1] as List<ProfileBioLink>;
        linkedAccounts = results[2] as List<LinkedChessAccount>;
        gameReviews = results[3] as List<GameReviewSummary>;
        stats = results[4] as ProfileStats?;

        // Also check local database for linked usernames if not from server
        if (linkedAccounts.isEmpty) {
          linkedAccounts = await _getLinkedAccountsFromLocalOrProfile(profile);
        }
      } else {
        // Other user's profile - only fetch public data
        // DO NOT call getLinkedAccounts() or getProfileStats() as they return
        // the current user's data (using auth.uid() internally)
        final results = await Future.wait([
          ProfileService.getProfile(userId),
          ProfileService.getBioLinks(userId),
          ProfileService.getUserBoards(userId), // Get public boards
        ]);

        profile = results[0] as ProfileData?;
        bioLinks = results[1] as List<ProfileBioLink>;
        final boards = results[2] as List<UserBoard>;

        // For other users, get chess account info from their profile data
        if (profile != null) {
          linkedAccounts = _buildLinkedAccountsFromProfile(profile);
        }

        // Update boards in state
        state = state.copyWith(boards: boards);
      }

      // Update state with fresh data
      if (profile != null) {
        state = state.copyWith(
          profile: profile,
          stats: stats, // Only set for own profile
          bioLinks: bioLinks,
          linkedAccounts: linkedAccounts,
          gameReviews: gameReviews,
          isFromCache: false,
        );

        // Only cache own profile data
        if (isOwnProfile) {
          await ProfileCacheService.cacheAllProfileData(
            profile: profile,
            bioLinks: bioLinks,
            linkedAccounts: linkedAccounts,
            gameReviews: gameReviews,
          );

          // Always load boards for own profile if stats RPC failed (fallback for overview)
          if (stats == null && state.boards.isEmpty) {
            await loadBoards(forceRefresh: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching fresh data: $e');
      // Don't show error if we have cached data
      if (state.profile == null) {
        state = state.copyWith(error: 'Failed to load profile');
      }
    }
  }

  /// Build linked accounts list from profile data (for other users)
  List<LinkedChessAccount> _buildLinkedAccountsFromProfile(ProfileData profile) {
    final accounts = <LinkedChessAccount>[];

    if (profile.chessComUsername != null && profile.chessComUsername!.isNotEmpty) {
      accounts.add(LinkedChessAccount(
        id: 'profile_chesscom',
        platform: 'chesscom',
        username: profile.chessComUsername!,
        linkedAt: profile.createdAt,
      ));
    }
    if (profile.lichessUsername != null && profile.lichessUsername!.isNotEmpty) {
      accounts.add(LinkedChessAccount(
        id: 'profile_lichess',
        platform: 'lichess',
        username: profile.lichessUsername!,
        linkedAt: profile.createdAt,
      ));
    }

    return accounts;
  }

  /// Get linked accounts from local database or profile data
  Future<List<LinkedChessAccount>> _getLinkedAccountsFromLocalOrProfile(ProfileData? profile) async {
    final localAccounts = <LinkedChessAccount>[];

    // Check local database first
    final localProfile = await LocalDatabase.getUserProfile(userId);
    if (localProfile != null) {
      if (localProfile.chessComUsername != null && localProfile.chessComUsername!.isNotEmpty) {
        localAccounts.add(LinkedChessAccount(
          id: 'local_chesscom',
          platform: 'chesscom',
          username: localProfile.chessComUsername!,
          linkedAt: DateTime.now(),
        ));
      }
      if (localProfile.lichessUsername != null && localProfile.lichessUsername!.isNotEmpty) {
        localAccounts.add(LinkedChessAccount(
          id: 'local_lichess',
          platform: 'lichess',
          username: localProfile.lichessUsername!,
          linkedAt: DateTime.now(),
        ));
      }
    }

    // Also check profile data if still empty
    if (localAccounts.isEmpty && profile != null) {
      return _buildLinkedAccountsFromProfile(profile);
    }

    return localAccounts;
  }

  /// Load all profile data (force network fetch)
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _fetchFreshData();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('Error loading profile: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load profile',
      );
    }
  }

  // Cursors for pagination (track last created_at for public and private separately)
  DateTime? _cursorPublic;
  DateTime? _cursorPrivate;

  /// Load user boards (lazy loaded when tab is selected)
  Future<void> loadBoards({bool forceRefresh = false}) async {
    if (state.boards.isNotEmpty && !forceRefresh) {
      return; // Already loaded
    }

    // Reset cursors on fresh load
    _cursorPublic = null;
    _cursorPrivate = null;

    state = state.copyWith(isLoadingBoards: true, hasMoreBoards: true);

    try {
      List<UserBoard> boards;

      if (isOwnProfile) {
        // Use get_my_boards_paginated for own profile
        boards = await ProfileService.getMyBoards();

        // Update cursors based on returned boards
        _updateCursors(boards);
      } else {
        // Use direct query for other users (public boards only)
        boards = await ProfileService.getUserBoards(userId);
      }

      state = state.copyWith(
        boards: boards,
        isLoadingBoards: false,
        hasMoreBoards: boards.length >= 20, // Assume more if we got a full page
      );

      // Cache boards only for own profile
      if (isOwnProfile) {
        await ProfileCacheService.cacheUserBoards(boards);
      }
    } catch (e) {
      debugPrint('Error loading boards: $e');
      state = state.copyWith(isLoadingBoards: false);
    }
  }

  /// Load more boards (pagination)
  Future<void> loadMoreBoards() async {
    if (!isOwnProfile || state.isLoadingMoreBoards || !state.hasMoreBoards) {
      return;
    }

    state = state.copyWith(isLoadingMoreBoards: true);

    try {
      final newBoards = await ProfileService.getMyBoards(
        cursorPublic: _cursorPublic,
        cursorPrivate: _cursorPrivate,
      );

      if (newBoards.isEmpty) {
        state = state.copyWith(
          isLoadingMoreBoards: false,
          hasMoreBoards: false,
        );
        return;
      }

      // Update cursors
      _updateCursors(newBoards);

      // Append to existing boards
      final allBoards = [...state.boards, ...newBoards];

      state = state.copyWith(
        boards: allBoards,
        isLoadingMoreBoards: false,
        hasMoreBoards: newBoards.length >= 20,
      );
    } catch (e) {
      debugPrint('Error loading more boards: $e');
      state = state.copyWith(isLoadingMoreBoards: false);
    }
  }

  /// Update cursors based on loaded boards
  void _updateCursors(List<UserBoard> boards) {
    for (final board in boards) {
      if (board.isPublic) {
        if (_cursorPublic == null || board.createdAt.isBefore(_cursorPublic!)) {
          _cursorPublic = board.createdAt;
        }
      } else {
        if (_cursorPrivate == null || board.createdAt.isBefore(_cursorPrivate!)) {
          _cursorPrivate = board.createdAt;
        }
      }
    }
  }

  /// Change selected tab
  void selectTab(int index) {
    state = state.copyWith(selectedTab: index);

    // Load boards when boards tab is selected
    if (index == 1 && state.boards.isEmpty) {
      loadBoards();
    }
  }

  /// Refresh profile data (force fetch from network)
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      await _fetchFreshData();

      // Also refresh boards if they were loaded
      if (state.boards.isNotEmpty) {
        await loadBoards(forceRefresh: true);
      }

      state = state.copyWith(isRefreshing: false);
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
      state = state.copyWith(
        isRefreshing: false,
        error: 'Failed to refresh profile',
      );
    }
  }

  /// Clear cache and reload
  Future<void> clearCacheAndReload() async {
    await ProfileCacheService.clearCache();
    state = const ProfileState(isLoading: true);
    await loadProfile();
  }

  /// Update linked chess account
  Future<bool> updateLinkedAccount(String platform, String username) async {
    final success = await ProfileService.updateLinkedAccount(
      platform: platform,
      username: username,
    );

    if (success) {
      // Refresh linked accounts
      final accounts = await ProfileService.getLinkedAccounts(userId);
      state = state.copyWith(linkedAccounts: accounts);

      // Update cache
      await ProfileCacheService.cacheLinkedAccounts(accounts);
    }

    return success;
  }
}

/// Provider for profile state (parameterized by user ID)
final profileProvider = StateNotifierProvider.family<ProfileNotifier, ProfileState, String>(
  (ref, userId) => ProfileNotifier(userId),
);
