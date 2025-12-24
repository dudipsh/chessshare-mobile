class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? chessComUsername;
  final String? lichessUsername;
  final String subscriptionType;
  final DateTime? subscriptionEndDate;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.chessComUsername,
    this.lichessUsername,
    this.subscriptionType = 'FREE',
    this.subscriptionEndDate,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      chessComUsername: json['chess_com_username'] as String?,
      lichessUsername: json['lichess_username'] as String?,
      subscriptionType: json['subscription_type'] as String? ?? 'FREE',
      subscriptionEndDate: json['subscription_end_date'] != null
          ? DateTime.parse(json['subscription_end_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'chess_com_username': chessComUsername,
      'lichess_username': lichessUsername,
      'subscription_type': subscriptionType,
      'subscription_end_date': subscriptionEndDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    String? chessComUsername,
    String? lichessUsername,
    String? subscriptionType,
    DateTime? subscriptionEndDate,
    bool clearChessComUsername = false,
    bool clearLichessUsername = false,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      chessComUsername: clearChessComUsername ? null : (chessComUsername ?? this.chessComUsername),
      lichessUsername: clearLichessUsername ? null : (lichessUsername ?? this.lichessUsername),
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      createdAt: createdAt,
    );
  }

  bool get isPremium => subscriptionType != 'FREE';

  int get dailyAnalysisLimit => isPremium ? -1 : 2; // -1 = unlimited
}
