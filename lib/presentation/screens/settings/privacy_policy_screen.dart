import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              title: '1. Introduction',
              content:
                  'Welcome to MindMate AI ("we," "our," or "us"). We are committed to protecting your privacy and personal information. '
                  'This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mental health support application.',
            ),

            _buildSection(
              context,
              title: '2. Information We Collect',
              content:
                  'We collect information that you provide directly to us, including:\n\n'
                  '• Personal Information: Name, email address, profile information\n'
                  '• Mental Health Data: Mood logs, journal entries, chat conversations\n'
                  '• Usage Data: App interactions, feature usage, session duration\n'
                  '• Device Information: Device type, operating system, unique device identifiers',
            ),

            _buildSection(
              context,
              title: '3. How We Use Your Information',
              content:
                  'We use the collected information for:\n\n'
                  '• Providing personalized AI-powered mental health support\n'
                  '• Analyzing mood patterns and providing insights\n'
                  '• Improving our services and user experience\n'
                  '• Sending notifications and reminders (with your consent)\n'
                  '• Ensuring the security and integrity of our services',
            ),

            _buildSection(
              context,
              title: '4. Data Storage and Security',
              content:
                  'Your data is stored securely using Google Firebase Cloud services with enterprise-grade encryption. '
                  'We implement industry-standard security measures including:\n\n'
                  '• End-to-end encryption for sensitive data\n'
                  '• Secure authentication protocols\n'
                  '• Regular security audits\n'
                  '• Access controls and monitoring\n\n'
                  'However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
            ),

            _buildSection(
              context,
              title: '5. AI and Third-Party Services',
              content:
                  'We use Google Gemini AI to provide conversational support. Your chat messages are processed by this AI service. '
                  'We do not share your personal information with the AI service beyond what is necessary for providing the service. '
                  'AI-generated responses are not substitutes for professional medical advice.',
            ),

            _buildSection(
              context,
              title: '6. Data Retention',
              content:
                  'We retain your personal information for as long as your account is active or as needed to provide services. '
                  'You can request deletion of your account and data at any time through the app settings. '
                  'Upon deletion request, we will delete or anonymize your data within 30 days, except where we are required to retain it by law.',
            ),

            _buildSection(
              context,
              title: '7. Your Rights (GDPR Compliance)',
              content:
                  'Under GDPR and similar regulations, you have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Correct inaccurate data\n'
                  '• Request deletion of your data\n'
                  '• Export your data in a portable format\n'
                  '• Object to data processing\n'
                  '• Withdraw consent at any time\n\n'
                  'To exercise these rights, please use the data export and account deletion features in app settings.',
            ),

            _buildSection(
              context,
              title: '8. Children\'s Privacy',
              content:
                  'Our service is not intended for users under 13 years of age. We do not knowingly collect personal information from children under 13. '
                  'If you are a parent or guardian and believe your child has provided us with personal information, please contact us.',
            ),

            _buildSection(
              context,
              title: '9. Changes to This Privacy Policy',
              content:
                  'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page '
                  'and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
            ),

            _buildSection(
              context,
              title: '10. Medical Disclaimer',
              content:
                  'MindMate AI is not a substitute for professional medical advice, diagnosis, or treatment. '
                  'If you are experiencing a mental health crisis, please contact emergency services or a mental health professional immediately. '
                  'The AI-generated content is for informational and support purposes only.',
            ),

            _buildSection(
              context,
              title: '11. Contact Us',
              content:
                  'If you have questions or concerns about this Privacy Policy, please contact us at:\n\n'
                  'Email: support@mindmate-ai.com\n'
                  'Website: www.mindmate-ai.com',
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your privacy and security are our top priorities. We are committed to protecting your mental health data.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
