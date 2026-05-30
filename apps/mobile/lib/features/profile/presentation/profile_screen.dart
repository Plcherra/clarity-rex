import 'package:flutter/material.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/mfa_enrollment_screen.dart';
import '../application/profile_controller.dart';

final class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profileController,
    required this.authController,
    this.signOut,
  });

  final ProfileController profileController;
  final AuthController authController;
  final Future<void> Function()? signOut;

  Future<void> _openMfaSettings(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => MfaEnrollmentScreen(controller: authController),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final currentName = profileController.profile?.fullName?.trim() ?? '';
    final controller = TextEditingController(text: currentName);
    try {
      final nextName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit profile name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (nextName == null || nextName.isEmpty || nextName == currentName) {
        return;
      }
      await profileController.updateCurrentProfile(fullName: nextName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileController.errorMessage ?? 'Could not update profile.',
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final handler = signOut;
    if (handler == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in when you are ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await handler();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: profileController,
      builder: (context, _) {
        final profile = profileController.profile;
        final name = profile?.fullName?.trim();
        final email =
            profile?.email?.trim() ?? authController.currentUser?.email ?? '';

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _ProfileHeader(
                name: name == null || name.isEmpty ? 'Clarity user' : name,
                email: email,
              ),
              const SizedBox(height: 16),
              _ProfileActionTile(
                icon: Icons.badge_outlined,
                title: 'Profile name',
                subtitle: name == null || name.isEmpty ? 'Add your name' : name,
                onTap: () => _editName(context),
              ),
              const SizedBox(height: 10),
              _ProfileActionTile(
                icon: Icons.verified_user_outlined,
                title: 'Multi-factor authentication',
                subtitle: 'Authenticator app setup and security options',
                onTap: () => _openMfaSettings(context),
              ),
              const SizedBox(height: 10),
              if (signOut != null)
                _ProfileActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Leave this device signed out of Clarity',
                  destructive: true,
                  onTap: () => _confirmSignOut(context),
                ),
            ],
          ),
        );
      },
    );
  }
}

final class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFEDE8DC),
              foregroundColor: const Color(0xFF3D392F),
              child: Text(
                initial,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = destructive ? cs.error : cs.onSurface;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: Icon(icon, color: destructive ? cs.error : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.24)),
        ),
        titleTextStyle: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

