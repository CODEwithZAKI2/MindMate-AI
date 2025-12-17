import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/routes.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait for a minimum splash duration for better UX
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authState = ref.read(authStateProvider);

    authState.when(
      data: (user) {
        if (user == null) {
          // No user, navigate to onboarding/sign in
          context.go(Routes.onboarding);
        } else {
          // Check if user completed onboarding
          if (!user.onboardingComplete) {
            context.go(Routes.onboarding);
          } else if (user.disclaimerAcceptedAt == null) {
            // User completed onboarding but hasn't accepted disclaimer
            context.go(Routes.disclaimer);
          } else {
            // User is fully set up, go to home
            context.go(Routes.home);
          }
        }
      },
      loading: () {
        // Still loading, wait a bit more
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _checkAuthState();
        });
      },
      error: (error, stack) {
        // Error checking auth, go to sign in
        context.go(Routes.signIn);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Icon(
              Icons.psychology_rounded,
              size: 120,
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(height: 24),
            // App Name
            Text(
              'MindMate AI',
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            Text(
              'Your AI Companion for Mental Wellness',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
