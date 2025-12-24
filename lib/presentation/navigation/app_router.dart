import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/routes.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/disclaimer/disclaimer_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/mood/mood_check_in_screen.dart';
import '../screens/mood/mood_history_dashboard_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chat_history_screen.dart';
import '../screens/chat/unified_chat_screen.dart';
import './main_shell.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/settings/terms_of_service_screen.dart';

// Placeholder screens for features not yet implemented
class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Mood - Coming Soon')),
      );
}

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Insights - Coming Soon')),
      );
}

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Exercises - Coming Soon')),
      );
}

/// Router provider with auth state integration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash & Onboarding
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.disclaimer,
        name: 'disclaimer',
        builder: (context, state) => const DisclaimerScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: Routes.signIn,
        name: 'signIn',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.signUp,
        name: 'signUp',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Main App Routes - Now using MainShell with bottom nav
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (context, state) => const MainShell(),
      ),
      
      // Chat routes
      GoRoute(
        path: Routes.chat,
        name: 'chat',
        builder: (context, state) => const UnifiedChatScreen(),
      ),
      GoRoute(
        path: Routes.chatHistory,
        name: 'chatHistory',
        builder: (context, state) => const ChatHistoryScreen(),
      ),
      
      // Mood routes
      GoRoute(
        path: Routes.moodCheckIn,
        name: 'moodCheckIn',
        builder: (context, state) => const MoodCheckInScreen(),
      ),
      GoRoute(
        path: Routes.moodHistory,
        name: 'moodHistory',
        builder: (context, state) => const MoodHistoryDashboardScreen(),
      ),
      GoRoute(
        path: Routes.insights,
        name: 'insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: Routes.exercises,
        name: 'exercises',
        builder: (context, state) => const ExercisesScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        name: 'privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: Routes.terms,
        name: 'terms',
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),

    // Redirect logic based on auth state
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final isAuthenticated = authState.hasValue && authState.value != null;
      final user = authState.value;

        const disclaimerReminderDays = 180;
        final needsDisclaimerReminder = user?.disclaimerAcceptedAt != null &&
          DateTime.now()
              .difference(user!.disclaimerAcceptedAt!)
              .inDays >=
            disclaimerReminderDays;

      final currentPath = state.matchedLocation;

      // Don't redirect while auth is loading (let splash handle it)
      if (isAuthLoading && currentPath == Routes.splash) {
        return null;
      }

      // Auth pages (can access when not authenticated)
      final isOnAuthPage = currentPath.startsWith('/signin') ||
          currentPath.startsWith('/signup') ||
          currentPath == Routes.onboarding;

      // Public pages
      final isOnPublicPage = currentPath == Routes.splash || isOnAuthPage;

      // If not authenticated and trying to access protected page
      if (!isAuthenticated && !isOnPublicPage) {
        return Routes.signIn;
      }

      // If authenticated, check onboarding and disclaimer
      if (isAuthenticated && user != null) {
        // Skip auth pages if already authenticated
        if (isOnAuthPage &&
            user.onboardingComplete &&
            user.disclaimerAcceptedAt != null &&
            user.ageVerified) {
          return Routes.home;
        }

        // Force onboarding if not completed
        if (!user.onboardingComplete && currentPath != Routes.onboarding) {
          return Routes.onboarding;
        }

        // Force disclaimer if not accepted
        if (user.onboardingComplete &&
            (!user.ageVerified || user.disclaimerAcceptedAt == null || needsDisclaimerReminder) &&
            currentPath != Routes.disclaimer) {
          return Routes.disclaimer;
        }
      }

      return null; // No redirect needed
    },
  );
});
