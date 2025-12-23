import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../models/profile_data.dart';
import '../services/profile_cache_service.dart';
import '../services/profile_service.dart';

/// State for the profile feature
class ProfileState {
  final ProfileData? profile;
  final List<ProfileBioLink> bioLinks;
  final List<LinkedChessAccount> linkedAccounts;
  final List<UserBoard> boards;
  final List<GameReviewSummary> gameReviews;
  final bool isLoading;
  final bool isLoadingBoards;
  final bool isRefreshing; // Loading fresh data while showing cached
  final bool isFromCache; // Data is from cache (may be stale)
  final String? error;
  final int selectedTab; // 0: Overview, 1: Boards, 2: Games

  const ProfileState({
    this.profile,
    this.bioLinks = const [],
    this.linkedAccounts = const [],
    this.boards = const [],
    this.gameReviews = const [],
    this.isLoading = false,
    this.isLoadingBoards = false,
    this.isRefreshing = false,
    this.isFromCache = false,
    this.error,
    this.selectedTab = 0,
  });

  ProfileState copyWith({
    ProfileData? profile,
    List<ProfileBioLink>? bioLinks,
    List<LinkedChessAccount>? linkedAccounts,
    List<UserBoard>? boards,
    List<GameReviewSummary>? gameReviews,
    bool? isLoading,
    bool? isLoadingBoards,
    bool? isRefreshing,
    bool? isFromCache,
    String? error,
    int? selectedTab,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      bioLinks: bioLinks ?? this.bioLinks,
      linkedAccounts: linkedAccounts ?? this.linkedAccounts,
      boards: boards ?? this.boards,
      gameReviews: gameReviews ?? this.gameReviews,
      isLoading: isLoading ?? this.isLoading,
      isLoadingBoards: isLoadingBoards ?? this.isLoadingBoards,
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

  ProfileNotifier(this.userId) : super(const ProfileState(isLoading: true)) {
    _initProfile();
  }

  /// Initialize profile - load from cache first, then fetch fresh data
  Future<void> _initProfile() async {
    // Try to load from cache first for instant UI
    final hasCachedData = await _loadFromCache();

    if (hasCachedData) {
      // Have cached data - show it immediately and refresh in background
      state = state.copyWith(isRefreshing: true);
      await _fetchFreshData();
      state = state.copyWith(isRefreshing: false);
    } else {
      // No cached data - need to fetch from network
      await loadProfile();
    }
  }

  /// Load profile data from cache
  Future<bool> _loadFromCache() async {
    try {
      final isCacheValid = await ProfileCacheService.isCacheValid();

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
        debugPrint('Loaded profile from cache (valid: $isCacheValid)');
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
      // Load profile data in parallel
      final results = await Future.wait([
        ProfileService.getProfile(userId),
        ProfileService.getBioLinks(userId),
        ProfileService.getLinkedAccounts(userId),
        ProfileService.getGameReviews(userId),
      ]);

      final profile = results[0] as ProfileData?;
      final bioLinks = results[1] as List<ProfileBioLink>;
      var linkedAccounts = results[2] as List<LinkedChessAccount>;
      final gameReviews = results[3] as List<GameReviewSummary>;

      // Also check local database for linked usernames if not from server
      if (linkedAccounts.isEmpty) {
        final localProfile = await LocalDatabase.getUserProfile(userId);
        final localAccounts = <LinkedChessAccount>[];

        // Check local database first
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
          if (profile.chessComUsername != null && profile.chessComUsername!.isNotEmpty) {
            localAccounts.add(LinkedChessAccount(
              id: 'profile_chesscom',
              platform: 'chesscom',
              username: profile.chessComUsername!,
              linkedAt: DateTime.now(),
            ));
          }
          if (profile.lichessUsername != null && profile.lichessUsername!.isNotEmpty) {
            localAccounts.add(LinkedChessAccount(
              id: 'profile_lichess',
              platform: 'lichess',
              username: profile.lichessUsername!,
              linkedAt: DateTime.now(),
            ));
          }
        }

        linkedAccounts = localAccounts;
      }

      // Update state with fresh data
      if (profile != null) {
        state = state.copyWith(
          profile: profile,
          bioLinks: bioLinks,
          linkedAccounts: linkedAccounts,
          gameReviews: gameReviews,
          isFromCache: false,
        );

        // Cache the fresh data
        await ProfileCacheService.cacheAllProfileData(
          profile: profile,
          bioLinks: bioLinks,
          linkedAccounts: linkedAccounts,
          gameReviews: gameReviews,
        );
        debugPrint('Profile data fetched and cached');

        // Also load boards for Overview tab stats (if not already loaded)
        if (state.boards.isEmpty) {
          await loadBoards();
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

  /// Load user boards (lazy loaded when tab is selected)
  Future<void> loadBoards({bool forceRefresh = false}) async {
    if (state.boards.isNotEmpty && !forceRefresh) return; // Already loaded

    state = state.copyWith(isLoadingBoards: true);

    try {
      final boards = await ProfileService.getUserBoards(userId);
      state = state.copyWith(
        boards: boards,
        isLoadingBoards: false,
      );

      // Cache boards
      await ProfileCacheService.cacheUserBoards(boards);
    } catch (e) {
      debugPrint('Error loading boards: $e');
      state = state.copyWith(isLoadingBoards: false);
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
