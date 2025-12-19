import 'package:equatable/equatable.dart';

/// Domain entity representing a user in the system
class User extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool onboardingComplete;
  final DateTime? disclaimerAcceptedAt;
  final bool ageVerified;
  final DateTime? ageVerifiedAt;
  final String subscriptionTier; // 'free' or 'premium'
  final DateTime? subscriptionExpiresAt;
  final String timezone;
  final String preferredLanguage;
  final String accountStatus; // 'active', 'suspended', 'deleted'

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.lastActiveAt,
    required this.onboardingComplete,
    this.disclaimerAcceptedAt,
    this.ageVerified = false,
    this.ageVerifiedAt,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.timezone = 'UTC',
    this.preferredLanguage = 'en',
    this.accountStatus = 'active',
  });

  bool get isPremium =>
      subscriptionTier == 'premium' &&
      (subscriptionExpiresAt == null ||
          subscriptionExpiresAt!.isAfter(DateTime.now()));

  bool get isActive => accountStatus == 'active';

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? onboardingComplete,
    DateTime? disclaimerAcceptedAt,
    bool? ageVerified,
    DateTime? ageVerifiedAt,
    String? subscriptionTier,
    DateTime? subscriptionExpiresAt,
    String? timezone,
    String? preferredLanguage,
    String? accountStatus,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      disclaimerAcceptedAt: disclaimerAcceptedAt ?? this.disclaimerAcceptedAt,
        ageVerified: ageVerified ?? this.ageVerified,
        ageVerifiedAt: ageVerifiedAt ?? this.ageVerifiedAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      timezone: timezone ?? this.timezone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      accountStatus: accountStatus ?? this.accountStatus,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        createdAt,
        lastActiveAt,
        onboardingComplete,
        disclaimerAcceptedAt,
        ageVerified,
        ageVerifiedAt,
        subscriptionTier,
        subscriptionExpiresAt,
        timezone,
        preferredLanguage,
        accountStatus,
      ];
}
