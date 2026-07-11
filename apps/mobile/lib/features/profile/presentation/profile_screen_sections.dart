import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import 'package:clarity/features/usage_admin/presentation/owner_usage_profile_entry.dart';
import '../application/locale_controller.dart';
import '../application/profile_controller.dart';
import '../application/theme_mode_controller.dart';
import 'profile_screen_widgets.dart';

/// Desktop two-column profile settings body.
class ProfileDesktopSections extends StatelessWidget {
  const ProfileDesktopSections({
    super.key,
    required this.profileController,
    required this.themeModeController,
    required this.localeController,
    required this.displayName,
    required this.onEditName,
    required this.onOpenMfa,
    required this.onOpenUsage,
    this.onSignOut,
  });

  final ProfileController profileController;
  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final String? displayName;
  final VoidCallback onEditName;
  final VoidCallback onOpenMfa;
  final VoidCallback onOpenUsage;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = profileController.profile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileSectionLabel(l10n.profileAccountSection),
              const SizedBox(height: 8),
              ProfileActionGroup(
                children: [
                  ProfileActionTile(
                    icon: Icons.badge_outlined,
                    title: l10n.profileNameTitle,
                    subtitle: displayName == null || displayName!.isEmpty
                        ? l10n.profileAddYourName
                        : displayName!,
                    onTap: onEditName,
                  ),
                  ProfileActionTile(
                    icon: Icons.verified_user_outlined,
                    title: l10n.profileMfaTitle,
                    subtitle: l10n.profileMfaSubtitle,
                    onTap: onOpenMfa,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ProfileSectionLabel(l10n.profileRexVoiceSection),
              const SizedBox(height: 8),
              ProfileActionGroup(
                children: [
                  ProfileActionTile(
                    icon: Icons.graphic_eq_rounded,
                    title: l10n.profileVoiceUsageTitle,
                    subtitle: l10n.profileVoiceUsageSubtitle,
                    onTap: onOpenUsage,
                  ),
                ],
              ),
              const OwnerUsageProfileEntry(),
              if (onSignOut != null) ...[
                const SizedBox(height: 18),
                ProfileSectionLabel(l10n.profileSessionSection),
                const SizedBox(height: 8),
                ProfileActionGroup(
                  children: [
                    ProfileActionTile(
                      icon: Icons.logout_rounded,
                      title: l10n.commonSignOut,
                      subtitle: l10n.profileSignOutSubtitle,
                      destructive: true,
                      onTap: onSignOut!,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileSectionLabel(l10n.profileAppearance),
              const SizedBox(height: 8),
              ProfileThemeInlineControl(controller: themeModeController),
              const SizedBox(height: 18),
              ProfileSectionLabel(l10n.profileProactiveInsightsTitle),
              const SizedBox(height: 8),
              ProfileActionGroup(
                children: [
                  ProfileProactiveInsightsTile(
                    enabled: profile?.proactiveInsightsEnabled ?? false,
                    isLoading: profileController.isLoading,
                    onChanged: (enabled) async {
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
              ProfileSectionLabel(l10n.profileLanguage),
              const SizedBox(height: 8),
              ProfileLanguageInlineControl(controller: localeController),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact single-column profile settings body.
class ProfileCompactSections extends StatelessWidget {
  const ProfileCompactSections({
    super.key,
    required this.profileController,
    required this.themeModeController,
    required this.localeController,
    required this.displayName,
    required this.onEditName,
    required this.onOpenMfa,
    required this.onOpenUsage,
    required this.onOpenAppearance,
    required this.onOpenLanguage,
    this.onSignOut,
  });

  final ProfileController profileController;
  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final String? displayName;
  final VoidCallback onEditName;
  final VoidCallback onOpenMfa;
  final VoidCallback onOpenUsage;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenLanguage;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = profileController.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(l10n.profileAccountSection),
        const SizedBox(height: 8),
        ProfileActionGroup(
          children: [
            ProfileActionTile(
              icon: Icons.badge_outlined,
              title: l10n.profileNameTitle,
              subtitle: displayName == null || displayName!.isEmpty
                  ? l10n.profileAddYourName
                  : displayName!,
              onTap: onEditName,
            ),
            ProfileActionTile(
              icon: Icons.verified_user_outlined,
              title: l10n.profileMfaTitle,
              subtitle: l10n.profileMfaSubtitle,
              onTap: onOpenMfa,
            ),
          ],
        ),
        const SizedBox(height: 18),
        ProfileSectionLabel(l10n.profileRexVoiceSection),
        const SizedBox(height: 8),
        ProfileActionGroup(
          children: [
            ProfileActionTile(
              icon: Icons.graphic_eq_rounded,
              title: l10n.profileVoiceUsageTitle,
              subtitle: l10n.profileVoiceUsageSubtitle,
              onTap: onOpenUsage,
            ),
          ],
        ),
        const OwnerUsageProfileEntry(),
        const SizedBox(height: 18),
        ProfileSectionLabel(l10n.profileAppearance),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: themeModeController,
          builder: (context, _) {
            return ProfileActionGroup(
              children: [
                ProfileActionTile(
                  icon: Icons.contrast_rounded,
                  title: l10n.profileAppearance,
                  subtitle: profileThemeModeLabel(
                    context,
                    themeModeController.themeMode,
                  ),
                  onTap: onOpenAppearance,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        ProfileSectionLabel(l10n.profileProactiveInsightsTitle),
        const SizedBox(height: 8),
        ProfileActionGroup(
          children: [
            ProfileProactiveInsightsTile(
              enabled: profile?.proactiveInsightsEnabled ?? false,
              isLoading: profileController.isLoading,
              onChanged: (enabled) async {
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
        ProfileSectionLabel(l10n.profileLanguage),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: localeController,
          builder: (context, _) {
            return ProfileActionGroup(
              children: [
                ProfileActionTile(
                  icon: Icons.translate_rounded,
                  title: l10n.profileLanguage,
                  subtitle: localeController.label,
                  onTap: onOpenLanguage,
                ),
              ],
            );
          },
        ),
        if (onSignOut != null) ...[
          const SizedBox(height: 18),
          ProfileSectionLabel(l10n.profileSessionSection),
          const SizedBox(height: 8),
          ProfileActionGroup(
            children: [
              ProfileActionTile(
                icon: Icons.logout_rounded,
                title: l10n.commonSignOut,
                subtitle: l10n.profileSignOutSubtitle,
                destructive: true,
                onTap: onSignOut!,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ProfileProactiveInsightsTile extends StatelessWidget {
  const ProfileProactiveInsightsTile({
    super.key,
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
  });

  final bool enabled;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Icon(
        Icons.notifications_active_outlined,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      ),
      title: Text(l10n.profileProactiveInsightsTitle),
      subtitle: Text(l10n.profileProactiveInsightsSubtitle),
      value: enabled,
      onChanged: isLoading ? null : onChanged,
    );
  }
}
