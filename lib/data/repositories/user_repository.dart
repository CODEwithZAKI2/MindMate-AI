import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/preferences_model.dart';
import '../../domain/entities/user.dart';

/// Repository for user profile and preferences management
class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get user profile stream
  Stream<User> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => UserModel.fromFirestore(doc).toEntity());
  }

  // Get user profile
  Future<User> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      throw Exception('User profile not found');
    }
    return UserModel.fromFirestore(doc).toEntity();
  }

  // Update user profile
  Future<void> updateUserProfile(User user) async {
    final userModel = UserModel.fromEntity(user);
    await _firestore
        .collection('users')
        .doc(user.id)
        .update(userModel.toFirestore());
  }

  // Update profile field
  Future<void> updateProfileField(String userId, String field, dynamic value) async {
    await _firestore.collection('users').doc(userId).update({field: value});
  }

  // Get user preferences
  Future<UserPreferencesModel> getUserPreferences(String userId) async {
    final doc = await _firestore.collection('user_preferences').doc(userId).get();
    
    if (!doc.exists) {
      // Return default preferences if none exist
      return UserPreferencesModel.defaultPreferences(userId);
    }
    
    return UserPreferencesModel.fromFirestore(doc);
  }

  // Update user preferences
  Future<void> updateUserPreferences(UserPreferencesModel preferences) async {
    await _firestore
        .collection('user_preferences')
        .doc(preferences.userId)
        .set(preferences.toFirestore(), SetOptions(merge: true));
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    await _firestore.collection('user_preferences').doc(userId).set({
      'notifications': preferences.toMap(),
    }, SetOptions(merge: true));
  }

  // Update privacy preferences
  Future<void> updatePrivacyPreferences(
    String userId,
    PrivacyPreferences preferences,
  ) async {
    await _firestore.collection('user_preferences').doc(userId).set({
      'privacy': preferences.toMap(),
    }, SetOptions(merge: true));
  }

  // Update wellness preferences
  Future<void> updateWellnessPreferences(
    String userId,
    WellnessPreferences preferences,
  ) async {
    await _firestore.collection('user_preferences').doc(userId).set({
      'wellness': preferences.toMap(),
    }, SetOptions(merge: true));
  }

  // Update UI preferences
  Future<void> updateUIPreferences(
    String userId,
    UIPreferences preferences,
  ) async {
    await _firestore.collection('user_preferences').doc(userId).set({
      'ui': preferences.toMap(),
    }, SetOptions(merge: true));
  }

  // Update streak
  Future<void> updateStreak(String userId, int currentStreak) async {
    await _firestore.collection('users').doc(userId).update({
      'currentStreak': currentStreak,
      'lastCheckInDate': DateTime.now().toIso8601String(),
    });
  }

  // Increment total check-ins
  Future<void> incrementTotalCheckIns(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'totalCheckIns': FieldValue.increment(1),
    });
  }

  // Update subscription
  Future<void> updateSubscription({
    required String userId,
    required String tier,
    DateTime? expiresAt,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'subscriptionTier': tier,
      'subscriptionExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
    });
  }

  // Deactivate account
  Future<void> deactivateAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'accountStatus': 'inactive',
    });
  }

  // Reactivate account
  Future<void> reactivateAccount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'accountStatus': 'active',
    });
  }
}
