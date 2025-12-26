import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart';
import '../../providers/data_export_provider.dart';
import '../../../core/constants/routes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please sign in'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Profile Section - Centered
                _buildProfileSection(
                  context,
                  theme,
                  user.displayName,
                  user.email,
                  ref,
                ),
                const SizedBox(height: 32),

                // General Section
                _buildSectionWithItems(
                  context,
                  theme,
                  sectionTitle: 'General',
                  items: [
                    _SettingsItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      trailing: _buildChevron(theme),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notifications settings coming soon'),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.language_outlined,
                      title: 'Language',
                      trailingText: 'English',
                      trailing: _buildChevron(theme),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Language settings coming soon'),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: theme.brightness == Brightness.dark,
                        onChanged: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Theme switching coming soon'),
                            ),
                          );
                        },
                      ),
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Data & Privacy Section
                _buildSectionWithItems(
                  context,
                  theme,
                  sectionTitle: 'Data & Privacy',
                  items: [
                    _SettingsItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      trailing: _buildChevron(theme),
                      onTap: () => context.push(Routes.privacy),
                    ),
                    _SettingsItem(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      trailing: _buildChevron(theme),
                      onTap: () => context.push(Routes.terms),
                    ),
                    _SettingsItem(
                      icon: Icons.download_outlined,
                      title: 'Export My Data',
                      trailing: _buildChevron(theme),
                      onTap: () => _showExportDataDialog(context, ref),
                    ),
                    _SettingsItem(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete Account',
                      iconColor: theme.colorScheme.error,
                      textColor: theme.colorScheme.error,
                      trailing: _buildChevron(
                        theme,
                        color: theme.colorScheme.error,
                      ),
                      onTap: () => _showDeleteAccountDialog(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // About Section
                _buildSectionWithItems(
                  context,
                  theme,
                  sectionTitle: 'About',
                  items: [
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      trailingText: '1.0.0',
                      trailing: null,
                      onTap: null,
                    ),
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      trailing: _buildChevron(theme),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Help center coming soon'),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.feedback_outlined,
                      title: 'Send Feedback',
                      trailing: _buildChevron(theme),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback form coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Sign Out Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InkWell(
                    onTap: () => _showSignOutDialog(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: theme.colorScheme.error,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildChevron(ThemeData theme, {Color? color}) {
    return Icon(
      Icons.chevron_right_rounded,
      color: color ?? theme.colorScheme.onSurface.withOpacity(0.4),
      size: 24,
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    ThemeData theme,
    String displayName,
    String email,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        // Avatar with edit badge
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile editing coming soon'),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Name with edit icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Email
        Text(
          email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionWithItems(
    BuildContext context,
    ThemeData theme, {
    required String sectionTitle,
    required List<_SettingsItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 32,
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              const SizedBox(width: 12),
              Text(
                sectionTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items
          ...items.map((item) => _buildSettingsListItem(context, theme, item)),
        ],
      ),
    );
  }

  Widget _buildSettingsListItem(
    BuildContext context,
    ThemeData theme,
    _SettingsItem item,
  ) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (item.iconColor ?? theme.colorScheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                size: 22,
                color: item.iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: item.textColor ?? theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (item.trailingText != null) ...[
              Text(
                item.trailingText!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (item.trailing != null) item.trailing!,
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go(Routes.signIn);
                  }
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This action cannot be undone. All your data will be permanently deleted immediately.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text('To confirm, please enter your password:'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !isDeleting,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isDeleting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          isDeleting
                              ? null
                              : () async {
                                if (passwordController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter your password',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => isDeleting = true);

                                try {
                                  final userId = ref.read(
                                    currentUserIdProvider,
                                  );
                                  if (userId == null)
                                    throw Exception('User not found');

                                  // Re-authenticate user
                                  final user =
                                      firebase_auth
                                          .FirebaseAuth
                                          .instance
                                          .currentUser;
                                  if (user?.email == null)
                                    throw Exception('Email not found');

                                  final credential = firebase_auth
                                      .EmailAuthProvider.credential(
                                    email: user!.email!,
                                    password: passwordController.text,
                                  );
                                  await user.reauthenticateWithCredential(
                                    credential,
                                  );

                                  // Delete all user data from Firestore
                                  final dataExportService = ref.read(
                                    dataExportServiceProvider,
                                  );
                                  await dataExportService.deleteAllUserData(
                                    userId,
                                  );

                                  // Delete Firebase Auth account
                                  await user.delete();

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account deleted successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    context.go(Routes.signIn);
                                  }
                                } catch (e) {
                                  setState(() => isDeleting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child:
                          isDeleting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Delete Permanently'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showExportDataDialog(BuildContext context, WidgetRef ref) {
    bool isExporting = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Export Data'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your data will be exported as a JSON file that you can save or share.',
                      ),
                      if (isExporting) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('Preparing your data...'),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isExporting
                              ? null
                              : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          isExporting
                              ? null
                              : () async {
                                setState(() => isExporting = true);

                                try {
                                  final userId = ref.read(
                                    currentUserIdProvider,
                                  );
                                  if (userId == null)
                                    throw Exception('User not found');

                                  // Export data
                                  final dataExportService = ref.read(
                                    dataExportServiceProvider,
                                  );
                                  final jsonData = await dataExportService
                                      .exportUserData(userId);

                                  // Save to temporary file
                                  final directory =
                                      await getTemporaryDirectory();
                                  final timestamp =
                                      DateTime.now().millisecondsSinceEpoch;
                                  final file = File(
                                    '${directory.path}/mindmate_data_$timestamp.json',
                                  );
                                  await file.writeAsString(jsonData);

                                  // Share the file
                                  await Share.shareXFiles(
                                    [XFile(file.path)],
                                    subject: 'MindMate AI - My Data Export',
                                    text:
                                        'Here is my exported data from MindMate AI',
                                  );

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Data exported successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isExporting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      child: const Text('Export'),
                    ),
                  ],
                ),
          ),
    );
  }
}

/// Helper class to hold settings item data
class _SettingsItem {
  final IconData icon;
  final String title;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
  });
}
