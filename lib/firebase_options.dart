// File generated manually from google-services.json
// Project: mindmate-ai-eada4

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCRoLHBMJELT-84JmXsEpVh1S-p_l65e5k',
    appId: '1:137877213010:android:6fc05464f968a11527348b',
    messagingSenderId: '137877213010',
    projectId: 'mindmate-ai-699b5',
    storageBucket: 'mindmate-ai-699b5.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEDQWP6vgn0Y4noo0DJFf0X26E75ZGeoA',
    appId: '1:137877213010:web:88b0a343f281739e27348b',
    messagingSenderId: '137877213010',
    projectId: 'mindmate-ai-699b5',
    authDomain: 'mindmate-ai-699b5.firebaseapp.com',
    storageBucket: 'mindmate-ai-699b5.firebasestorage.app',
    measurementId: 'G-KQ36L6ZJXB',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDBDtaz-38DS1GMNb0b78K6zsjMMcyMv-A',
    appId: '1:137877213010:ios:8796fcf94ebb1a3627348b',
    messagingSenderId: '137877213010',
    projectId: 'mindmate-ai-699b5',
    storageBucket: 'mindmate-ai-699b5.firebasestorage.app',
    iosClientId: '137877213010-2ua3csp3ggfgnm73eep1lp210v5g99h2.apps.googleusercontent.com',
    iosBundleId: 'com.mindmate.mindmateAi',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDBDtaz-38DS1GMNb0b78K6zsjMMcyMv-A',
    appId: '1:137877213010:ios:8796fcf94ebb1a3627348b',
    messagingSenderId: '137877213010',
    projectId: 'mindmate-ai-699b5',
    storageBucket: 'mindmate-ai-699b5.firebasestorage.app',
    iosClientId: '137877213010-2ua3csp3ggfgnm73eep1lp210v5g99h2.apps.googleusercontent.com',
    iosBundleId: 'com.mindmate.mindmateAi',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBEDQWP6vgn0Y4noo0DJFf0X26E75ZGeoA',
    appId: '1:137877213010:web:2df918894710145b27348b',
    messagingSenderId: '137877213010',
    projectId: 'mindmate-ai-699b5',
    authDomain: 'mindmate-ai-699b5.firebaseapp.com',
    storageBucket: 'mindmate-ai-699b5.firebasestorage.app',
    measurementId: 'G-S9D621TN8R',
  );

}