/// Subscription tiers with their limits
enum SubscriptionTier {
  free,
  basic,
  pro,
  admin;

  /// Get tier from string
  static SubscriptionTier fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'basic':
        return SubscriptionTier.basic;
      case 'pro':
        return SubscriptionTier.pro;
      case 'admin':
        return SubscriptionTier.admin;
      default:
        return SubscriptionTier.free;
    }
  }

  /// Display name
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.pro:
        return 'Pro';
      case SubscriptionTier.admin:
        return 'Admin';
    }
  }

  /// Monthly price in USD
  double get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.basic:
        return 4.99;
      case SubscriptionTier.pro:
        return 9.99;
      case SubscriptionTier.admin:
        return 0; // Admin is free
    }
  }
}

/// Limits configuration for each tier
class TierLimits {
  /// Game analyses per day
  final int dailyAnalyses;

  /// Board views per day
  final int dailyBoardViews;

  /// Whether user can access all variations (or just first)
  final bool allVariations;

  /// Maximum boards user can create
  final int maxBoards;

  /// Maximum saved mistakes for practice
  final int maxSavedMistakes;

  /// Daily puzzles per day
  final int dailyPuzzles;

  /// Can create clubs
  final bool canCreateClub;

  /// Can upload cover images
  final bool canUploadCover;

  /// Has priority support
  final bool prioritySupport;

  const TierLimits({
    required this.dailyAnalyses,
    required this.dailyBoardViews,
    required this.allVariations,
    required this.maxBoards,
    required this.maxSavedMistakes,
    required this.dailyPuzzles,
    required this.canCreateClub,
    required this.canUploadCover,
    required this.prioritySupport,
  });

  /// Unlimited value marker
  static const unlimited = 999999;

  /// Get limits for a specific tier
  static TierLimits forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return const TierLimits(
          dailyAnalyses: 2,
          dailyBoardViews: 10,
          allVariations: false,
          maxBoards: 0,
          maxSavedMistakes: 10,
          dailyPuzzles: 1,
          canCreateClub: false,
          canUploadCover: false,
          prioritySupport: false,
        );

      case SubscriptionTier.basic:
        return const TierLimits(
          dailyAnalyses: 10,
          dailyBoardViews: 50,
          allVariations: true,
          maxBoards: 5,
          maxSavedMistakes: 50,
          dailyPuzzles: 3,
          canCreateClub: false,
          canUploadCover: true,
          prioritySupport: false,
        );

      case SubscriptionTier.pro:
      case SubscriptionTier.admin:
        return TierLimits(
          dailyAnalyses: TierLimits.unlimited,
          dailyBoardViews: TierLimits.unlimited,
          allVariations: true,
          maxBoards: TierLimits.unlimited,
          maxSavedMistakes: TierLimits.unlimited,
          dailyPuzzles: 5,
          canCreateClub: true,
          canUploadCover: true,
          prioritySupport: true,
        );
    }
  }

  /// Check if a limit is unlimited
  bool isUnlimited(int value) => value >= unlimited;
}

/// Model representing a user's subscription
class UserSubscription {
  final String userId;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final bool isActive;

  const UserSubscription({
    required this.userId,
    required this.tier,
    this.expiresAt,
    this.isActive = true,
  });

  factory UserSubscription.free(String userId) {
    return UserSubscription(
      userId: userId,
      tier: SubscriptionTier.free,
      isActive: true,
    );
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['user_id'] as String,
      tier: SubscriptionTier.fromString(json['tier'] as String?),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Get limits for this subscription
  TierLimits get limits => TierLimits.forTier(tier);

  /// Check if subscription is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Effective tier (considering expiration)
  SubscriptionTier get effectiveTier {
    if (!isActive || isExpired) return SubscriptionTier.free;
    return tier;
  }
}
