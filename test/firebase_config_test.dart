import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate_ai/firebase_options.dart';

void main() {
  group('Firebase Configuration Tests', () {
    test('Android Firebase options should be configured correctly', () {
      final options = DefaultFirebaseOptions.android;

      expect(options.apiKey, isNotEmpty);
      expect(options.appId, isNotEmpty);
      expect(options.messagingSenderId, isNotEmpty);
      expect(options.projectId, 'mindmate-ai-eada4');
      expect(options.storageBucket, 'mindmate-ai-eada4.firebasestorage.app');
    });

    test('Firebase project ID should match', () {
      final options = DefaultFirebaseOptions.android;
      expect(options.projectId, contains('mindmate-ai'));
    });

    test('Firebase storage bucket should be valid', () {
      final options = DefaultFirebaseOptions.android;
      expect(options.storageBucket, endsWith('.firebasestorage.app'));
    });
  });
}
