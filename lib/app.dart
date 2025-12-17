import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';

/// Main app widget
class MindMateApp extends ConsumerWidget {
  const MindMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MindMate AI',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // TODO: Make this dynamic from settings

      // Routing
      routerConfig: router,

      // Builder for global wrappers
      builder: (context, child) {
        // Add error handling, overlays, etc. here if needed
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
