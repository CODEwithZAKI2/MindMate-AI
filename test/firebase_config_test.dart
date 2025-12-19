import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate_ai/firebase_options.dart';

void main() {
  group('Firebase Configuration Tests', () {
    test('Android Firebase options should be configured correctly', () {
      final options = DefaultFirebaseOptions.android;

      // Verify critical fields are present
      expect(options.apiKey, isNotNull);
      expect(options.apiKey, isNotEmpty);
      expect(options.appId, isNotNull);
      expect(options.appId, isNotEmpty);
      expect(options.messagingSenderId, isNotNull);
      expect(options.messagingSenderId, isNotEmpty);
      expect(options.projectId, isNotNull);
      expect(options.projectId, isNotEmpty);
    });

    test('Firebase project ID should match', () {
      final options = DefaultFirebaseOptions.android;
      expect(options.projectId, contains('mindmate'));
    });

    test('Firebase storage bucket should be configured', () {
      final options = DefaultFirebaseOptions.android;
      expect(options.storageBucket, isNotNull);
      if (options.storageBucket != null) {
        expect(options.storageBucket, isNotEmpty);
      }
    });
  });
}
