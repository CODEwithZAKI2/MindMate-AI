import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tzlib;
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/utils/logger.dart';
import 'firebase_options.dart';
import 'presentation/providers/notification_provider.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger (development mode for now)
  AppLogger.init(isProduction: false);
  AppLogger.info('🚀 MindMate AI starting...');

  // Set preferred orientations (portrait only for mental wellness app)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize timezone database and set local timezone
  tz.initializeTimeZones();
  try {
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    AppLogger.info('📍 Device timezone detected: $localTimezone');
    tzlib.setLocalLocation(tzlib.getLocation(localTimezone));
    AppLogger.info('✅ Timezone set to: ${tzlib.local.name}');
  } catch (e) {
    AppLogger.warning('⚠️ Could not detect timezone, using UTC: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.info('✅ Firebase initialized');

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  AppLogger.info('✅ SharedPreferences initialized');

  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  AppLogger.info('✅ NotificationService initialized');

  // Run app with Riverpod and provider overrides
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MindMateApp(),
    ),
  );

  AppLogger.info('✅ MindMate AI started successfully');
}
