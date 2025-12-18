import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
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
              title: '1. Acceptance of Terms',
              content:
                  'By accessing or using MindMate AI ("the App"), you agree to be bound by these Terms of Service. '
                  'If you do not agree to these terms, please do not use the App. We reserve the right to modify these terms at any time, '
                  'and your continued use of the App constitutes acceptance of any changes.',
            ),

            _buildSection(
              context,
              title: '2. Description of Service',
              content:
                  'MindMate AI is a mental health support application that provides:\n\n'
                  '• AI-powered conversational support\n'
                  '• Mood tracking and pattern analysis\n'
                  '• Journaling features\n'
                  '• Mental health insights and recommendations\n\n'
                  'The App is designed to provide support and information, but is NOT a substitute for professional medical advice, diagnosis, or treatment.',
            ),

            _buildSection(
              context,
              title: '3. Medical Disclaimer',
              content:
                  'IMPORTANT: MindMate AI does not provide medical advice. The App is for informational and support purposes only. '
                  'Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. '
                  'Never disregard professional medical advice or delay in seeking it because of something you have read or received through the App.\n\n'
                  'If you are experiencing a mental health crisis or emergency, please contact:\n'
                  '• Emergency services (911 in the US)\n'
                  '• National Suicide Prevention Lifeline: 988\n'
                  '• Crisis Text Line: Text HOME to 741741',
            ),

            _buildSection(
              context,
              title: '4. User Eligibility',
              content:
                  'You must be at least 13 years old to use MindMate AI. Users between 13-18 years old must have parental or guardian consent. '
                  'By using the App, you represent that you meet these age requirements.',
            ),

            _buildSection(
              context,
              title: '5. User Responsibilities',
              content:
                  'You agree to:\n\n'
                  '• Provide accurate information when creating your account\n'
                  '• Keep your account credentials secure\n'
                  '• Use the App only for lawful purposes\n'
                  '• Not misuse or attempt to harm the App or its services\n'
                  '• Not share content that is harmful, offensive, or violates others\' rights\n'
                  '• Understand that AI responses are not medical advice',
            ),

            _buildSection(
              context,
              title: '6. AI-Generated Content',
              content:
                  'The App uses Google Gemini AI to generate conversational responses. While we strive for accuracy and helpfulness:\n\n'
                  '• AI responses may contain errors or inaccuracies\n'
                  '• AI cannot replace human judgment or professional expertise\n'
                  '• You should not rely solely on AI-generated content for important decisions\n'
                  '• We are not responsible for any decisions made based on AI responses',
            ),

            _buildSection(
              context,
              title: '7. Privacy and Data Use',
              content:
                  'Your use of the App is subject to our Privacy Policy. By using the App, you consent to our collection, use, and disclosure of information '
                  'as described in the Privacy Policy. We take your privacy seriously and implement security measures to protect your data.',
            ),

            _buildSection(
              context,
              title: '8. Intellectual Property',
              content:
                  'The App and its original content, features, and functionality are owned by MindMate AI and are protected by international copyright, trademark, '
                  'patent, trade secret, and other intellectual property laws. You may not copy, modify, distribute, sell, or lease any part of the App.',
            ),

            _buildSection(
              context,
              title: '9. Limitation of Liability',
              content:
                  'TO THE MAXIMUM EXTENT PERMITTED BY LAW:\n\n'
                  '• The App is provided "as is" without warranties of any kind\n'
                  '• We are not liable for any indirect, incidental, or consequential damages\n'
                  '• We are not responsible for any decisions made based on App content\n'
                  '• Our total liability shall not exceed the amount you paid for the App (if any)\n'
                  '• We are not liable for service interruptions or data loss',
            ),

            _buildSection(
              context,
              title: '10. Third-Party Services',
              content:
                  'The App may contain links to third-party services or integrate with third-party APIs (such as Google Gemini AI). '
                  'We are not responsible for the content, privacy policies, or practices of any third-party services. '
                  'Your use of third-party services is at your own risk.',
            ),

            _buildSection(
              context,
              title: '11. Account Termination',
              content:
                  'We reserve the right to suspend or terminate your account at any time for:\n\n'
                  '• Violation of these Terms of Service\n'
                  '• Fraudulent or illegal activity\n'
                  '• Behavior that harms other users or the App\n\n'
                  'You may delete your account at any time through the app settings. Upon deletion, your data will be removed within 30 days.',
            ),

            _buildSection(
              context,
              title: '12. Changes to Service',
              content:
                  'We reserve the right to modify, suspend, or discontinue any aspect of the App at any time without notice. '
                  'We are not liable to you or any third party for any modifications, suspensions, or discontinuance of the App.',
            ),

            _buildSection(
              context,
              title: '13. Governing Law',
              content:
                  'These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], '
                  'without regard to its conflict of law provisions. Any disputes arising from these Terms or the App shall be resolved in the courts of [Your Jurisdiction].',
            ),

            _buildSection(
              context,
              title: '14. Contact Information',
              content:
                  'If you have questions about these Terms of Service, please contact us at:\n\n'
                  'Email: legal@mindmate-ai.com\n'
                  'Website: www.mindmate-ai.com',
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important Notice',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If you are experiencing a mental health crisis, please contact emergency services or a crisis hotline immediately. '
                          'MindMate AI is not a substitute for professional help.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
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
