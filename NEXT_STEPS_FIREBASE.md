# Next Steps - Firebase Setup Guide 🔥

## Current Status
✅ Flutter project foundation complete  
✅ All dependencies installed  
✅ Core architecture in place  
⏳ Firebase configuration needed

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Enter project name: `mindmate-ai` (or your preferred name)
4. Enable Google Analytics (recommended)
5. Select or create Analytics account
6. Click "Create Project"

---

## Step 2: Add Android App

1. In Firebase Console, click Android icon
2. Enter package name: `com.mindmate.mindmate_ai`
3. App nickname: `MindMate AI`
4. Download `google-services.json`
5. Place file in: `android/app/google-services.json`
6. ✅ Google Services plugin already configured (completed)

---

## Step 3: Enable Authentication

1. In Firebase Console, go to **Authentication**
2. Click "Get Started"
3. Enable sign-in methods:
   - ✅ Email/Password
   - ✅ Google (configure OAuth consent screen)

### Google Sign-In Setup
1. In Authentication → Sign-in Method → Google
2. Click "Enable"
3. Add your SHA-1 fingerprint: `8B:DD:7F:DE:2E:92:8D:7F:28:D5:2A:83:1F:7E:98:BE:8A:4B:9E:A0`
4. Click "Save"
5. ✅ Done! The `google-services.json` file already contains all OAuth configuration needed

---

## Step 4: Set Up Firestore

1. In Firebase Console, go to **Firestore Database**
2. Click "Create database"
3. Choose location: `us-central` (or closest to users)
4. Start in **test mode** (we'll add security rules later)
5. Click "Enable"

### Initial Collections to Create
- `users`
- `moodLogs` (will be subcollection under users)
- `chatHistory` (will be subcollection under users)
- `preferences` (will be subcollection under users)
- `crisisEvents` (admin-only)

---

## Step 5: Configure Firestore Security Rules

In Firestore → Rules, paste:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check authentication
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read, write: if isOwner(userId);
      
      // User's mood logs
      match /moodLogs/{logId} {
        allow read, write: if isOwner(userId);
      }
      
      // User's chat history (read only, write via Cloud Functions)
      match /chatHistory/{sessionId} {
        allow read: if isOwner(userId);
        allow write: if false;
      }
      
      // User's preferences
      match /preferences/{doc} {
        allow read, write: if isOwner(userId);
      }
    }
    
    // Crisis events - admin only
    match /crisisEvents/{eventId} {
      allow read, write: if false;
    }
  }
}
```

Click "Publish"

---

## Step 6: Update Flutter Code

### Add Firebase initialization

In `lib/main.dart`, uncomment Firebase initialization:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Will be generated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppLogger.init(isProduction: false);
  AppLogger.info('🚀 MindMate AI starting...');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.info('✅ Firebase initialized');
  
  // ... rest of code
}
```

### Generate Firebase configuration

Run FlutterFire CLI:
```bash
# Install if not already installed
dart pub global activate flutterfire_cli

# Generate configuration
flutterfire configure
```

This creates `lib/firebase_options.dart` automatically.

---

## Step 7: Test Firebase Connection

Create a test file: `lib/core/services/firebase_service.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

class FirebaseService {
  static Future<bool> testConnection() async {
    try {
      final app = Firebase.app();
      AppLogger.info('Firebase app name: ${app.name}');
      
      // Test Firestore connection
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('test').limit(1).get();
      
      AppLogger.info('✅ Firebase connection successful');
      return true;
    } catch (e) {
      AppLogger.error('❌ Firebase connection failed', e);
      return false;
    }
  }
}
```

Run the test on app startup temporarily.

---

## Step 8: Create Auth Service

Create `lib/data/services/firebase_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email & password
  Future<User> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up with email & password
  Future<User> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<User> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw AuthException('Google sign-in cancelled');

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user!;
    } catch (e) {
      AppLogger.error('Google sign-in error', e);
      throw AuthException('Google sign-in failed');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Error handling
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
      default:
        return AuthException(e.message ?? 'Authentication failed');
    }
  }
}
```

---

## Step 9: Update API Endpoint

In `lib/core/constants/api_endpoints.dart`, update:

```dart
// Replace with your actual Firebase project ID
static const String baseUrl =
    'https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/api';
```

---

## Step 10: Verify Setup

Run these commands:

```bash
# Clean build
flutter clean
flutter pub get

# Run on device
flutter run

# Check for Firebase warnings
flutter run --verbose
```

---

## Expected Result

After setup:
- ✅ App launches without errors
- ✅ Firebase connects successfully
- ✅ Authentication methods available
- ✅ Firestore ready for data
- ✅ Security rules active

---

## Common Issues & Solutions

### Issue: "No Firebase App"
**Solution**: Ensure `Firebase.initializeApp()` is called before any Firebase usage

### Issue: "Google Sign-In failed"
**Solution**: Check SHA-1 fingerprint is added to Firebase project

### Issue: "Firestore permission denied"
**Solution**: Verify security rules are published

---

## Next After Firebase Setup

1. ✅ Implement authentication screens (SignIn, SignUp)
2. ✅ Create User model and repository
3. ✅ Build authentication provider with Riverpod
4. ✅ Add authentication guards to router
5. ✅ Create onboarding and disclaimer screens

---

## Resources

- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Auth Best Practices](https://firebase.google.com/docs/auth/admin/best-practices)

---

**Estimated Time**: 1-2 hours  
**Difficulty**: Medium  
**Priority**: HIGH (blocking for all other features)

---

*This guide assumes you have Firebase admin access and necessary credentials.*
