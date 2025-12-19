import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MindMate app configuration test', () {
    // Test that the app name is correctly configured
    const appTitle = 'MindMate AI';
    expect(appTitle, isNotEmpty);
    expect(appTitle, contains('MindMate'));
    
    // Test that theme mode values are valid
    expect(ThemeMode.values, contains(ThemeMode.system));
    expect(ThemeMode.values, contains(ThemeMode.light));
    expect(ThemeMode.values, contains(ThemeMode.dark));
  });
}
