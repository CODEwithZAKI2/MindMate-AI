import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mindmate_ai/app.dart';

void main() {
  testWidgets('MindMate app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MindMateApp(),
      ),
    );

    // Verify that the splash screen shows loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
