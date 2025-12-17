import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user.dart';

/// Data model for User with Firestore serialization
class UserModel {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool onboardingComplete;
  final DateTime? disclaimerAcceptedAt;
  final String subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final String timezone;
  final String preferredLanguage;
  final String accountStatus;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.lastActiveAt,
    required this.onboardingComplete,
    this.disclaimerAcceptedAt,
    this.subscriptionTier = 'free',
    this.subscriptionExpiresAt,
    this.timezone = 'UTC',
    this.preferredLanguage = 'en',
    this.accountStatus = 'active',
  });

  /// Convert User entity to UserModel
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      createdAt: user.createdAt,
      lastActiveAt: user.lastActiveAt,
      onboardingComplete: user.onboardingComplete,
      disclaimerAcceptedAt: user.disclaimerAcceptedAt,
      subscriptionTier: user.subscriptionTier,
      subscriptionExpiresAt: user.subscriptionExpiresAt,
      timezone: user.timezone,
      preferredLanguage: user.preferredLanguage,
      accountStatus: user.accountStatus,
    );
  }

  /// Convert Firestore document to UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp).toDate(),
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      disclaimerAcceptedAt: data['disclaimerAcceptedAt'] != null
          ? (data['disclaimerAcceptedAt'] as Timestamp).toDate()
          : null,
      subscriptionTier: data['subscriptionTier'] as String? ?? 'free',
      subscriptionExpiresAt: data['subscriptionExpiresAt'] != null
          ? (data['subscriptionExpiresAt'] as Timestamp).toDate()
          : null,
      timezone: data['timezone'] as String? ?? 'UTC',
      preferredLanguage: data['preferredLanguage'] as String? ?? 'en',
      accountStatus: data['accountStatus'] as String? ?? 'active',
    );
  }

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'onboardingComplete': onboardingComplete,
      'disclaimerAcceptedAt': disclaimerAcceptedAt != null
          ? Timestamp.fromDate(disclaimerAcceptedAt!)
          : null,
      'subscriptionTier': subscriptionTier,
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'timezone': timezone,
      'preferredLanguage': preferredLanguage,
      'accountStatus': accountStatus,
    };
  }

  /// Convert UserModel to User entity
  User toEntity() {
    return User(
      id: id,
      email: email,
      displayName: displayName,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
      onboardingComplete: onboardingComplete,
      disclaimerAcceptedAt: disclaimerAcceptedAt,
      subscriptionTier: subscriptionTier,
      subscriptionExpiresAt: subscriptionExpiresAt,
      timezone: timezone,
      preferredLanguage: preferredLanguage,
      accountStatus: accountStatus,
    );
  }
}
