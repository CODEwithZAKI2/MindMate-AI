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
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please sign in'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Section
              _buildSectionHeader(context, 'Profile'),
              _buildProfileCard(context, theme, user.displayName, user.email),
              const SizedBox(height: 24),

              // App Settings Section
              _buildSectionHeader(context, 'App Settings'),
              _buildSettingsCard(
                context,
                theme,
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications settings coming soon')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    subtitle: 'Toggle dark theme',
                    trailing: Switch(
                      value: theme.brightness == Brightness.dark,
                      onChanged: (value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Theme switching coming soon')),
                        );
                      },
                    ),
                    onTap: null,
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Language settings coming soon')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Data & Privacy Section
              _buildSectionHeader(context, 'Data & Privacy'),
              _buildSettingsCard(
                context,
                theme,
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => context.push(Routes.privacy),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => context.push(Routes.terms),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.download_outlined,
                    title: 'Export My Data',
                    subtitle: 'Download your data (GDPR)',
                    onTap: () {
                      _showExportDataDialog(context, ref);
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    textColor: theme.colorScheme.error,
                    iconColor: theme.colorScheme.error,
                    onTap: () {
                      _showDeleteAccountDialog(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // About Section
              _buildSectionHeader(context, 'About'),
              _buildSettingsCard(
                context,
                theme,
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info_outlined,
                    title: 'App Version',
                    subtitle: '1.0.0 (MVP)',
                    onTap: null,
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Help center coming soon')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feedback form coming soon')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sign Out Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _showSignOutDialog(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    ThemeData theme,
    String displayName,
    String email,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editing coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    ThemeData theme, {
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface;
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return ListTile(
      leading: Icon(icon, color: effectiveIconColor),
      title: Text(
        title,
        style: TextStyle(color: effectiveTextColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: effectiveTextColor.withOpacity(0.7),
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
              const Text(
                'To confirm, please enter your password:',
              ),
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
              onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your password')),
                        );
                        return;
                      }

                      setState(() => isDeleting = true);

                      try {
                        final userId = ref.read(currentUserIdProvider);
                        if (userId == null) throw Exception('User not found');

                        // Re-authenticate user
                        final user = firebase_auth.FirebaseAuth.instance.currentUser;
                        if (user?.email == null) throw Exception('Email not found');

                        final credential = firebase_auth.EmailAuthProvider.credential(
                          email: user!.email!,
                          password: passwordController.text,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Delete all user data from Firestore
                        final dataExportService = ref.read(dataExportServiceProvider);
                        await dataExportService.deleteAllUserData(userId);

                        // Delete Firebase Auth account
                        await user.delete();

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account deleted successfully'),
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
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
              onPressed: isExporting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isExporting
                  ? null
                  : () async {
                      setState(() => isExporting = true);

                      try {
                        final userId = ref.read(currentUserIdProvider);
                        if (userId == null) throw Exception('User not found');

                        // Export data
                        final dataExportService = ref.read(dataExportServiceProvider);
                        final jsonData = await dataExportService.exportUserData(userId);

                        // Save to temporary file
                        final directory = await getTemporaryDirectory();
                        final timestamp = DateTime.now().millisecondsSinceEpoch;
                        final file = File('${directory.path}/mindmate_data_$timestamp.json');
                        await file.writeAsString(jsonData);

                        // Share the file
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          subject: 'MindMate AI - My Data Export',
                          text: 'Here is my exported data from MindMate AI',
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Data exported successfully!'),
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
