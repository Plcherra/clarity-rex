import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/clarity_native_layout.dart';
import 'package:clarity/features/usage_admin/presentation/owner_usage_profile_entry.dart';
import '../application/locale_controller.dart';
import '../application/theme_mode_controller.dart';
import 'profile_screen_widgets.dart';

/// Desktop two-column profile settings body.
class ProfileDesktopSections extends StatelessWidget {
  const ProfileDesktopSections({
    super.key,
    required this.themeModeController,
    required this.localeController,
    required this.displayName,
    required this.onEditName,
    required this.onOpenMfa,
    required this.onOpenLanguage,
    this.onSignOut,
    this.onDeleteAccount,
  });

  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final String? displayName;
  final VoidCallback onEditName;
  final VoidCallback onOpenMfa;
  final VoidCallback onOpenLanguage;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              const OwnerUsageProfileEntry(),
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
              ProfileSectionLabel(l10n.profileLanguage),
              const SizedBox(height: 8),
              ProfileActionGroup(
                children: [
                  ProfileLanguageTile(
                    controller: localeController,
                    onTap: onOpenLanguage,
                  ),
                ],
              ),
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
      ],
    );
  }
}

/// Compact single-column profile settings body.
class ProfileCompactSections extends StatelessWidget {
  const ProfileCompactSections({
    super.key,
    required this.themeModeController,
    required this.localeController,
    required this.displayName,
    required this.onEditName,
    required this.onOpenMfa,
    required this.onOpenAppearance,
    required this.onOpenLanguage,
    this.onSignOut,
    this.onDeleteAccount,
  });

  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final String? displayName;
  final VoidCallback onEditName;
  final VoidCallback onOpenMfa;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenLanguage;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            ProfileLanguageTile(
              controller: localeController,
              onTap: onOpenLanguage,
            ),
          ],
        ),
        const OwnerUsageProfileEntry(),
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

/// App language, in Profile.
///
/// It belongs here rather than under Companion: it sets the whole interface,
/// not just what Rex speaks, and someone changing it is thinking about the app
/// rather than about the assistant.
class ProfileLanguageTile extends StatelessWidget {
  const ProfileLanguageTile({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final LocaleController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ProfileActionTile(
          icon: Icons.translate_rounded,
          title: context.l10n.profileLanguage,
          subtitle: controller.label,
          onTap: onTap,
        );
      },
    );
  }
}
