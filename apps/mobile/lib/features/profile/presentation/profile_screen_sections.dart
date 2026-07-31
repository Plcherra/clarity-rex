import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/clarity_native_layout.dart';
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
    this.onDeleteAccount,
  });

  final ProfileController profileController;
  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final String? displayName;
  final VoidCallback onEditName;
  final VoidCallback onOpenMfa;
  final VoidCallback onOpenUsage;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;

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
              if (onSignOut != null || onDeleteAccount != null) ...[
                const SizedBox(height: 18),
                ProfileSectionLabel(l10n.profileSessionSection),
                const SizedBox(height: 8),
                ProfileActionGroup(
                  children: [
                    if (onSignOut != null)
                      ProfileActionTile(
                        icon: Icons.logout_rounded,
                        title: l10n.commonSignOut,
                        subtitle: l10n.profileSignOutSubtitle,
                        destructive: true,
                        onTap: onSignOut!,
                      ),
                    if (onDeleteAccount != null)
                      ProfileActionTile(
                        icon: Icons.delete_forever_outlined,
                        title: l10n.profileDeleteAccountConfirm,
                        subtitle: l10n.profileDeleteAccountSubtitle,
                        destructive: true,
                        onTap: onDeleteAccount!,
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
///
/// Phone layout: fewer section headers (no label that repeats the only row
/// title), one Preferences group for appearance/language/insights.
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
    this.onDeleteAccount,
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
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = profileController.profile;
    final sectionGap = ClarityNativeLayout.active(context)
        ? ClarityNativeLayout.sectionGap(context)
        : 18.0;

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
        SizedBox(height: sectionGap),
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
        SizedBox(height: sectionGap),
        ProfileSectionLabel(l10n.commonPreferences),
        const SizedBox(height: 8),
        ProfileActionGroup(
          children: [
            ListenableBuilder(
              listenable: themeModeController,
              builder: (context, _) {
                return ProfileActionTile(
                  icon: Icons.contrast_rounded,
                  title: l10n.profileAppearance,
                  subtitle: profileThemeModeLabel(
                    context,
                    themeModeController.themeMode,
                  ),
                  onTap: onOpenAppearance,
                );
              },
            ),
            ListenableBuilder(
              listenable: localeController,
              builder: (context, _) {
                return ProfileActionTile(
                  icon: Icons.translate_rounded,
                  title: l10n.profileLanguage,
                  subtitle: localeController.label,
                  onTap: onOpenLanguage,
                );
              },
            ),
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
        if (onSignOut != null || onDeleteAccount != null) ...[
          SizedBox(height: sectionGap),
          ProfileActionGroup(
            children: [
              if (onSignOut != null)
                ProfileActionTile(
                  icon: Icons.logout_rounded,
                  title: l10n.commonSignOut,
                  subtitle: l10n.profileSignOutSubtitle,
                  destructive: true,
                  onTap: onSignOut!,
                ),
              if (onDeleteAccount != null)
                ProfileActionTile(
                  icon: Icons.delete_forever_outlined,
                  title: l10n.profileDeleteAccountConfirm,
                  subtitle: l10n.profileDeleteAccountSubtitle,
                  destructive: true,
                  onTap: onDeleteAccount!,
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
    final theme = Theme.of(context);
    final native = ClarityNativeLayout.active(context);
    final pad = native
        ? ClarityNativeLayout.listRowPadding(context)
        : const EdgeInsets.symmetric(horizontal: 16);

    return SwitchListTile.adaptive(
      contentPadding: pad,
      secondary: Icon(
        Icons.notifications_active_outlined,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
      title: Text(
        l10n.profileProactiveInsightsTitle,
        style: (native ? theme.textTheme.bodyMedium : theme.textTheme.titleSmall)
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        l10n.profileProactiveInsightsSubtitle,
        maxLines: native ? 2 : 4,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.25,
        ),
      ),
      value: enabled,
      onChanged: isLoading ? null : onChanged,
    );
  }
}
