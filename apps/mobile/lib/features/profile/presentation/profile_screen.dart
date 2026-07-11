import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/clarity_locale_catalog.dart';
import '../../../theme/clarity_colors.dart';
import '../../../theme/clarity_sheet_insets.dart';
import '../../../widgets/clarity_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/mfa_enrollment_screen.dart';
import '../application/locale_controller.dart';
import '../application/profile_controller.dart';
import '../application/theme_mode_controller.dart';
import 'usage_summary_screen.dart';
import 'package:clarity/features/usage_admin/presentation/owner_usage_profile_entry.dart';

final class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profileController,
    required this.authController,
    required this.themeModeController,
    required this.localeController,
    this.signOut,
  });

  final ProfileController profileController;
  final AuthController authController;
  final ThemeModeController themeModeController;
  final LocaleController localeController;
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

  Future<void> _openAppearance(BuildContext context) async {
    await showClarityModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: themeModeController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.profileAppearance,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final mode in ThemeMode.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_themeModeLabel(context, mode)),
                      trailing: themeModeController.themeMode == mode
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () async {
                        await themeModeController.setThemeMode(mode);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openLanguage(BuildContext context) async {
    await showClarityModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: localeController,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.profileLanguage,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final supported in localeController.enabledLocales)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(localeController.labelFor(supported)),
                      trailing:
                          localeController.localeTag ==
                              ClarityLocaleCatalog.localeTagFor(supported)
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () async {
                        await localeController.setLocale(supported);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.profileLanguageUpdated(
                                  localeController.labelFor(supported),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editName(BuildContext context) async {
    final l10n = context.l10n;
    final currentName = profileController.profile?.fullName?.trim() ?? '';
    final controller = TextEditingController(text: currentName);
    try {
      final nextName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.profileEditNameTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.authFullNameLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: Text(l10n.commonSave),
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
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdatedSnackBar)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileController.errorMessage ?? l10n.profileUpdateFailed,
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileSignOutTitle),
        content: Text(l10n.profileSignOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonSignOut),
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
    final l10n = context.l10n;
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
            title: Text(l10n.profileScreenTitle),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: Scrollbar(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _ProfileHeader(
                  name: name == null || name.isEmpty
                      ? l10n.profileDefaultUserName
                      : name,
                  email: email,
                ),
                const SizedBox(height: 18),
                _ProfileSectionLabel(l10n.profileAccountSection),
                const SizedBox(height: 8),
                _ProfileActionGroup(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.badge_outlined,
                      title: l10n.profileNameTitle,
                      subtitle: name == null || name.isEmpty
                          ? l10n.profileAddYourName
                          : name,
                      onTap: () => _editName(context),
                    ),
                    _ProfileActionTile(
                      icon: Icons.verified_user_outlined,
                      title: l10n.profileMfaTitle,
                      subtitle: l10n.profileMfaSubtitle,
                      onTap: () => _openMfaSettings(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProfileSectionLabel(l10n.profileRexVoiceSection),
                const SizedBox(height: 8),
                _ProfileActionGroup(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.graphic_eq_rounded,
                      title: l10n.profileVoiceUsageTitle,
                      subtitle: l10n.profileVoiceUsageSubtitle,
                      onTap: () => _openUsage(context),
                    ),
                  ],
                ),
                const OwnerUsageProfileEntry(),
                const SizedBox(height: 18),
                _ProfileSectionLabel(l10n.profileAppearance),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: themeModeController,
                  builder: (context, _) {
                    return _ProfileActionGroup(
                      children: [
                        _ProfileActionTile(
                          icon: Icons.contrast_rounded,
                          title: l10n.profileAppearance,
                          subtitle: _themeModeLabel(
                            context,
                            themeModeController.themeMode,
                          ),
                          onTap: () => _openAppearance(context),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _ProfileSectionLabel(l10n.profileProactiveInsightsTitle),
                const SizedBox(height: 8),
                _ProfileActionGroup(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      secondary: Icon(
                        Icons.notifications_active_outlined,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                      title: Text(l10n.profileProactiveInsightsTitle),
                      subtitle: Text(l10n.profileProactiveInsightsSubtitle),
                      value: profile?.proactiveInsightsEnabled ?? false,
                      onChanged: profileController.isLoading
                          ? null
                          : (enabled) async {
                              try {
                                await profileController
                                    .updateProactiveInsightsEnabled(enabled);
                              } on Object {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      profileController.errorMessage ??
                                          l10n.profileUpdateFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProfileSectionLabel(l10n.profileLanguage),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: localeController,
                  builder: (context, _) {
                    return _ProfileActionGroup(
                      children: [
                        _ProfileActionTile(
                          icon: Icons.translate_rounded,
                          title: l10n.profileLanguage,
                          subtitle: localeController.label,
                          onTap: () => _openLanguage(context),
                        ),
                      ],
                    );
                  },
                ),
                if (signOut != null) ...[
                  const SizedBox(height: 18),
                  _ProfileSectionLabel(l10n.profileSessionSection),
                  const SizedBox(height: 8),
                  _ProfileActionGroup(
                    children: [
                      _ProfileActionTile(
                        icon: Icons.logout_rounded,
                        title: l10n.commonSignOut,
                        subtitle: l10n.profileSignOutSubtitle,
                        destructive: true,
                        onTap: () => _confirmSignOut(context),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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
    final colors = context.clarityColors;
    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return ClarityCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: colors.surface.withValues(alpha: 0.72),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
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
                  context.l10n.profileHeaderLabel,
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
    final colors = context.clarityColors;
    return ClarityCard(
      padding: EdgeInsets.zero,
      highlighted: false,
      backgroundColor: colors.surface.withValues(alpha: 0.58),
      child: Column(children: children),
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
    final colors = context.clarityColors;
    final color = destructive ? cs.error : colors.textPrimary;

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
                  color: (destructive ? cs.error : colors.accent).withValues(
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
                    color: destructive ? cs.error : colors.accent,
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

String _themeModeLabel(BuildContext context, ThemeMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    ThemeMode.system => l10n.themeSystem,
    ThemeMode.dark => l10n.themeDark,
    ThemeMode.light => l10n.themeLight,
  };
}
