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
/// Matches the web app (chessy-linker) limits exactly
class TierLimits {
  /// Game reviews/analyses per day
  final int dailyGameReviews;

  /// Board views per day (for FREE users)
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

  /// Can upload/change cover images
  final bool canChangeCover;

  /// Has priority support
  final bool prioritySupport;

  const TierLimits({
    required this.dailyGameReviews,
    required this.dailyBoardViews,
    required this.allVariations,
    required this.maxBoards,
    required this.maxSavedMistakes,
    required this.dailyPuzzles,
    required this.canCreateClub,
    required this.canChangeCover,
    required this.prioritySupport,
  });

  /// Unlimited value marker
  static const unlimited = 999999;

  /// Get limits for a specific tier (matches web app exactly)
  static TierLimits forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        // FREE: 3 daily board views, 5 max boards, 1 daily game review
        return const TierLimits(
          dailyGameReviews: 1,
          dailyBoardViews: 3,
          allVariations: false,
          maxBoards: 5,
          maxSavedMistakes: 10,
          dailyPuzzles: 1,
          canCreateClub: false,
          canChangeCover: false,
          prioritySupport: false,
        );

      case SubscriptionTier.basic:
        // BASIC ($4.99/mo): 50 daily board views, 20 max boards, 3 daily game reviews
        return const TierLimits(
          dailyGameReviews: 3,
          dailyBoardViews: 50,
          allVariations: true,
          maxBoards: 20,
          maxSavedMistakes: 50,
          dailyPuzzles: 3,
          canCreateClub: true,
          canChangeCover: true,
          prioritySupport: false,
        );

      case SubscriptionTier.pro:
      case SubscriptionTier.admin:
        // PRO ($9.99/mo): Unlimited everything
        return TierLimits(
          dailyGameReviews: TierLimits.unlimited,
          dailyBoardViews: TierLimits.unlimited,
          allVariations: true,
          maxBoards: TierLimits.unlimited,
          maxSavedMistakes: TierLimits.unlimited,
          dailyPuzzles: TierLimits.unlimited,
          canCreateClub: true,
          canChangeCover: true,
          prioritySupport: true,
        );
    }
  }

  /// Check if a limit is unlimited
  bool isUnlimited(int value) => value >= unlimited;
}

/// Model representing a user's subscription (matches profiles table in Supabase)
class UserSubscription {
  final String userId;
  final SubscriptionTier tier;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? lemonSqueezySubscriptionId;
  final String? lemonSqueezyCustomerId;

  const UserSubscription({
    required this.userId,
    required this.tier,
    this.startDate,
    this.endDate,
    this.lemonSqueezySubscriptionId,
    this.lemonSqueezyCustomerId,
  });

  factory UserSubscription.free(String userId) {
    return UserSubscription(
      userId: userId,
      tier: SubscriptionTier.free,
    );
  }

  /// Parse from profiles table response
  factory UserSubscription.fromProfile(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['id'] as String? ?? '',
      tier: SubscriptionTier.fromString(json['subscription_type'] as String?),
      startDate: json['subscription_start_date'] != null
          ? DateTime.tryParse(json['subscription_start_date'] as String)
          : null,
      endDate: json['subscription_end_date'] != null
          ? DateTime.tryParse(json['subscription_end_date'] as String)
          : null,
      lemonSqueezySubscriptionId:
          json['lemonsqueezy_subscription_id'] as String?,
      lemonSqueezyCustomerId: json['lemonsqueezy_customer_id'] as String?,
    );
  }

  /// Parse from RPC get_user_subscription_info response
  factory UserSubscription.fromRpc(String userId, Map<String, dynamic> json) {
    return UserSubscription(
      userId: userId,
      tier: SubscriptionTier.fromString(json['subscription_type'] as String?),
      startDate: json['subscription_start_date'] != null
          ? DateTime.tryParse(json['subscription_start_date'] as String)
          : null,
      endDate: json['subscription_end_date'] != null
          ? DateTime.tryParse(json['subscription_end_date'] as String)
          : null,
      lemonSqueezySubscriptionId:
          json['lemonsqueezy_subscription_id'] as String?,
      lemonSqueezyCustomerId: json['lemonsqueezy_customer_id'] as String?,
    );
  }

  /// Get limits for this subscription
  TierLimits get limits => TierLimits.forTier(tier);

  /// Check if subscription is expired
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Check if subscription is active (not expired and has valid tier)
  bool get isActive {
    if (tier == SubscriptionTier.free) return true;
    return !isExpired;
  }

  /// Effective tier (considering expiration)
  SubscriptionTier get effectiveTier {
    if (isExpired) return SubscriptionTier.free;
    return tier;
  }

  /// Check if user has an active paid subscription
  bool get hasPaidSubscription =>
      tier != SubscriptionTier.free && isActive;

  /// Check if subscription can be managed (has LemonSqueezy IDs)
  bool get canManageSubscription =>
      lemonSqueezySubscriptionId != null && lemonSqueezyCustomerId != null;
}
