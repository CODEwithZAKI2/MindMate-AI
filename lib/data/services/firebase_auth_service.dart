import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';

/// Service to handle Firebase Authentication
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get currently authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<User> signInWithEmail(String email, String password) async {
    try {
      AppLogger.info('Attempting sign in for: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('✅ Sign in successful for: $email');
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Sign in failed', e);
      throw _handleAuthException(e);
    }
  }

  /// Create new account with email and password
  Future<User> signUpWithEmail(String email, String password) async {
    try {
      AppLogger.info('Creating new account for: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('✅ Account created successfully for: $email');
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Sign up failed', e);
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google account
  Future<User> signInWithGoogle() async {
    try {
      AppLogger.info('Starting Google sign-in...');

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        AppLogger.info('Google sign-in cancelled by user');
        throw AuthException('Google sign-in cancelled');
      }

      AppLogger.info('Google account selected: ${googleUser.email}');

      // Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      AppLogger.info('✅ Google sign-in successful');
      return userCredential.user!;
    } catch (e, stackTrace) {
      AppLogger.error('Google sign-in error', e, stackTrace);
      if (e is AuthException) rethrow;
      throw AuthException('Google sign-in failed');
    }
  }

  /// Sign out from all providers
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out...');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      AppLogger.info('✅ Sign out successful');
    } catch (e, stackTrace) {
      AppLogger.error('Sign out failed', e, stackTrace);
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      AppLogger.info('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      AppLogger.info('✅ Password reset email sent');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Password reset failed', e);
      throw _handleAuthException(e);
    }
  }

  /// Convert FirebaseAuthException to custom exception
  AuthException _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return UserNotFoundException();
      case 'wrong-password':
        return InvalidCredentialsException();
      case 'email-already-in-use':
        return EmailAlreadyInUseException();
      case 'weak-password':
        return WeakPasswordException();
      case 'user-disabled':
        return UserDisabledException();
      case 'invalid-email':
        return AuthException('Invalid email address');
      case 'operation-not-allowed':
        return AuthException('Operation not allowed');
      case 'too-many-requests':
        return AuthException('Too many requests. Please try again later.');
      default:
        return AuthException(e.message ?? 'Authentication failed');
    }
  }
}
