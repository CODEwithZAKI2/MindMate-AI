import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// Service to test Firebase connection
class FirebaseService {
  /// Test if Firebase is properly initialized and connected
  static Future<bool> testConnection() async {
    try {
      final app = Firebase.app();
      AppLogger.info('Firebase app name: ${app.name}');
      AppLogger.info('Firebase project ID: ${app.options.projectId}');

      // Test Firestore connection
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('test').limit(1).get();

      AppLogger.info('✅ Firebase connection successful');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Firebase connection failed', e, stackTrace);
      return false;
    }
  }
}
