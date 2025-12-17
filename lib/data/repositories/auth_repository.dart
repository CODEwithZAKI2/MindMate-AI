import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_auth_service.dart';
import '../models/user_model.dart';
import '../../domain/entities/user.dart';

/// Repository for authentication and user profile management
class AuthRepository {
  final FirebaseAuthService _authService;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuthService? authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService ?? FirebaseAuthService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Auth state stream
  Stream<User?> get authStateChanges {
    return _authService.authStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return await getUserProfile(firebaseUser.uid);
    });
  }

  // Current user ID
  String? get currentUserId => _authService.currentUser?.uid;

  // Sign in with email and password
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final firebaseUser = await _authService.signInWithEmail(email, password);
    return await getUserProfile(firebaseUser.uid);
  }

  // Sign up with email and password
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final firebaseUser = await _authService.signUpWithEmail(email, password);

    // Create user profile
    final user = User(
      id: firebaseUser.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      onboardingComplete: true,
      subscriptionTier: 'free',
      accountStatus: 'active',
    );

    await createUserProfile(user);
    return user;
  }

  // Sign in with Google
  Future<User> signInWithGoogle() async {
    final firebaseUser = await _authService.signInWithGoogle();
    
    // Check if user profile exists
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    
    if (userDoc.exists) {
      return UserModel.fromFirestore(userDoc).toEntity();
    }

    // Create new profile for Google sign-in
    final user = User(
      id: firebaseUser.uid,
      email: firebaseUser.email!,
      displayName: firebaseUser.displayName ?? 'User',
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      onboardingComplete: true,
      subscriptionTier: 'free',
      accountStatus: 'active',
    );

    await createUserProfile(user);
    return user;
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  // Get user profile
  Future<User> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      throw Exception('User profile not found');
    }
    final user = UserModel.fromFirestore(doc).toEntity();
    
    // Migration: Fix old users with onboardingComplete: false
    if (!user.onboardingComplete) {
      await _firestore.collection('users').doc(userId).update({
        'onboardingComplete': true,
      });
      return user.copyWith(onboardingComplete: true);
    }
    
    return user;
  }

  // Create user profile
  Future<void> createUserProfile(User user) async {
    final userModel = UserModel.fromEntity(user);
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(userModel.toFirestore());
  }

  // Update user profile
  Future<void> updateUserProfile(User user) async {
    final userModel = UserModel.fromEntity(user);
    await _firestore
        .collection('users')
        .doc(user.id)
        .update(userModel.toFirestore());
  }

  // Update onboarding status
  Future<void> completeOnboarding(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'onboardingComplete': true,
    });
  }

  // Accept disclaimer
  Future<void> acceptDisclaimer(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'disclaimerAcceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update timezone
  Future<void> updateTimezone(String userId, String timezone) async {
    await _firestore.collection('users').doc(userId).update({
      'timezone': timezone,
    });
  }

  // Delete account
  Future<void> deleteAccount(String userId) async {
    // Delete user profile
    await _firestore.collection('users').doc(userId).delete();
    
    // Delete all user data (mood logs, chat sessions, etc.)
    await _deleteUserData(userId);
    
    // Delete Firebase Auth account
    await _authService.currentUser?.delete();
  }

  Future<void> _deleteUserData(String userId) async {
    final batch = _firestore.batch();

    // Delete mood logs
    final moodLogs = await _firestore
        .collection('mood_logs')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in moodLogs.docs) {
      batch.delete(doc.reference);
    }

    // Delete chat sessions
    final chatSessions = await _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in chatSessions.docs) {
      batch.delete(doc.reference);
    }

    // Delete preferences
    batch.delete(_firestore.collection('user_preferences').doc(userId));

    await batch.commit();
  }
}
