import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/routes.dart';

enum AgeOption { over18, under18 }

class DisclaimerScreen extends ConsumerStatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  ConsumerState<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends ConsumerState<DisclaimerScreen> {
  bool _isAccepted = false;
  bool _isLoading = false;
  AgeOption? _ageOption;

  Future<void> _acceptDisclaimer() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _showError('User not found. Please sign in again.');
      return;
    }

    if (_ageOption != AgeOption.over18) {
      _showError('You must confirm you are 18 or older to continue.');
      return;
    }

    if (!_isAccepted) {
      _showError('Please accept the disclaimer to continue.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .acceptDisclaimer(userId, isAgeVerified: true);
      
      // Invalidate auth state to force refresh
      ref.invalidate(authStateProvider);
      
      if (mounted) {
        // Wait a moment for the state to refresh
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          context.go(Routes.home);
        }
      }
    } catch (e) {
      print('Error accepting disclaimer: $e');
      if (mounted) {
        _showError('Failed to accept disclaimer: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Important Disclaimer'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning icon
                    Center(
                      child: Icon(
                        Icons.info_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'Before You Begin',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Disclaimer text
                    _buildDisclaimerSection(
                      title: 'Not a Substitute for Professional Care',
                      content:
                          'MindMate AI is designed to provide emotional support and wellness resources, but it is NOT a replacement for professional mental health care, therapy, or medical advice.',
                      theme: theme,
                    ),
                    _buildDisclaimerSection(
                      title: 'Crisis Support',
                      content:
                          'If you are experiencing a mental health crisis, suicidal thoughts, or need immediate help, please contact emergency services (911) or a crisis hotline immediately:\n\n'
                          '• National Suicide Prevention Lifeline: 988\n'
                          '• Crisis Text Line: Text HOME to 741741\n'
                          '• International Association for Suicide Prevention: iasp.info',
                      theme: theme,
                    ),
                    _buildDisclaimerSection(
                      title: 'AI Limitations',
                      content:
                          'MindMate AI uses artificial intelligence which may sometimes provide inaccurate, incomplete, or inappropriate responses. Always use your best judgment and consult with qualified professionals for important decisions.',
                      theme: theme,
                    ),
                    _buildDisclaimerSection(
                      title: 'Age Requirement',
                      content:
                          'You must be 18 years or older to use MindMate AI. If you are under 18, please use this service with parental guidance and supervision.',
                      theme: theme,
                    ),
                    _buildDisclaimerSection(
                      title: 'Privacy & Data',
                      content:
                          'Your conversations and data are encrypted and stored securely. We respect your privacy and follow GDPR guidelines. By continuing, you agree to our Privacy Policy and Terms of Service.',
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Age Verification (Required)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<AgeOption>(
                      title: const Text('I am 18 years or older'),
                      value: AgeOption.over18,
                      groupValue: _ageOption,
                      onChanged: (value) {
                        setState(() => _ageOption = value);
                      },
                    ),
                    RadioListTile<AgeOption>(
                      title: const Text('I am under 18'),
                      value: AgeOption.under18,
                      groupValue: _ageOption,
                      onChanged: (value) {
                        setState(() => _ageOption = value);
                      },
                    ),
                    if (_ageOption == AgeOption.under18) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'MindMate AI is for users 18+ only. If you are under 18, please seek support from a trusted adult or local helplines.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Acceptance checkbox
                    CheckboxListTile(
                      value: _isAccepted,
                      onChanged: (value) {
                        setState(() => _isAccepted = value ?? false);
                      },
                      title: Text(
                        'I have read and understood the disclaimer above',
                        style: theme.textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            // Accept button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _ageOption == AgeOption.over18 && _isAccepted && !_isLoading
                      ? _acceptDisclaimer
                      : null,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'I Accept and Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerSection({
    required String title,
    required String content,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onBackground.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
