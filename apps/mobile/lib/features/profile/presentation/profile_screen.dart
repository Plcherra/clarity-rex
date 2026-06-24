import 'package:flutter/material.dart';

import '../../../widgets/clarity_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/mfa_enrollment_screen.dart';
import '../application/profile_controller.dart';
import 'usage_summary_screen.dart';

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

  Future<void> _openUsage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (context) => const UsageSummaryScreen()),
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _ProfileHeader(
                name: name == null || name.isEmpty ? 'Clarity user' : name,
                email: email,
              ),
              const SizedBox(height: 18),
              const _ProfileSectionLabel('Account'),
              const SizedBox(height: 8),
              _ProfileActionGroup(
                children: [
                  _ProfileActionTile(
                    icon: Icons.badge_outlined,
                    title: 'Profile name',
                    subtitle: name == null || name.isEmpty
                        ? 'Add your name'
                        : name,
                    onTap: () => _editName(context),
                  ),
                  _ProfileActionTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Multi-factor authentication',
                    subtitle: 'Authenticator app setup and security options',
                    onTap: () => _openMfaSettings(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _ProfileSectionLabel('Rex and voice'),
              const SizedBox(height: 8),
              _ProfileActionGroup(
                children: [
                  _ProfileActionTile(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Voice usage',
                    subtitle: 'Minutes today, this week, and this month',
                    onTap: () => _openUsage(context),
                  ),
                ],
              ),
              if (signOut != null) ...[
                const SizedBox(height: 18),
                const _ProfileSectionLabel('Session'),
                const SizedBox(height: 8),
                _ProfileActionGroup(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      subtitle: 'Leave this device signed out of Clarity',
                      destructive: true,
                      onTap: () => _confirmSignOut(context),
                    ),
                  ],
                ),
              ],
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

    return ClarityCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.74),
      borderColor: cs.outlineVariant.withValues(alpha: 0.64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clarity profile',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
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
    );
  }
}

final class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.52),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.35,
      ),
    );
  }
}

final class _ProfileActionGroup extends StatelessWidget {
  const _ProfileActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClarityCard(
      padding: EdgeInsets.zero,
      highlighted: false,
      backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.48),
      borderColor: cs.outlineVariant.withValues(alpha: 0.56),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 64,
                color: cs.outlineVariant.withValues(alpha: 0.38),
              ),
            children[index],
          ],
        ],
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: (destructive ? cs.error : cs.primary).withValues(
                    alpha: destructive ? 0.12 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    icon,
                    size: 20,
                    color: destructive ? cs.error : cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: destructive
                            ? cs.error.withValues(alpha: 0.76)
                            : cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: destructive
                    ? cs.error.withValues(alpha: 0.72)
                    : cs.onSurface.withValues(alpha: 0.32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
