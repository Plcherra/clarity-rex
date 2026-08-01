import 'package:flutter/material.dart';

import '../../../core/layout/clarity_adaptive_overlay.dart';
import '../../../core/layout/clarity_breakpoints.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../core/layout/web_centered_dialog.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../rex/presentation/pages/companion_settings_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/mfa_enrollment_screen.dart';
import '../application/locale_controller.dart';
import '../application/profile_controller.dart';
import '../application/theme_mode_controller.dart';
import 'language_picker.dart';
import 'profile_screen_sections.dart';
import 'profile_screen_widgets.dart';

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

  Future<void> _openCompanion(BuildContext context) {
    return openCompanionSettings(context, profileController: profileController);
  }

  Future<void> _openLanguage(BuildContext context) {
    return showClarityLanguagePicker(context, localeController);
  }

  Future<void> _openAppearance(BuildContext context) async {
    await showClarityAdaptiveOverlay<void>(
      context: context,
      dialogMaxWidth: 420,
      dialogMaxHeight: 360,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: themeModeController,
          builder: (context, _) {
            return Padding(
              padding: ClarityNativeLayout.active(context)
                  ? ClarityNativeLayout.pagePadding(
                      context,
                      top: 16,
                      bottom: 20,
                    )
                  : const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                      title: Text(profileThemeModeLabel(context, mode)),
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

  Future<void> _editName(BuildContext context) async {
    final l10n = context.l10n;
    final currentName = profileController.profile?.fullName?.trim() ?? '';
    final controller = TextEditingController(text: currentName);
    try {
      final nextName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => wrapWebCenteredDialog(
          dialogContext,
          AlertDialog(
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
      builder: (dialogContext) => wrapWebCenteredDialog(
        dialogContext,
        AlertDialog(
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
      ),
    );
    if (confirmed == true) {
      await handler();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => wrapWebCenteredDialog(
        dialogContext,
        AlertDialog(
          title: Text(l10n.profileDeleteAccountTitle),
          content: Text(l10n.profileDeleteAccountBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.profileDeleteAccountConfirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await authController.deleteAccount();
    if (!context.mounted) return;
    final error = authController.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final desktop = isClarityDesktopLayout(context);
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
            thumbVisibility: desktop,
            child: ListView(
              padding: ClarityNativeLayout.active(context)
                  ? ClarityNativeLayout.pagePadding(
                      context,
                      top: 8,
                      bottom: 28,
                    )
                  : const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                ProfileHeader(
                  name: name == null || name.isEmpty
                      ? l10n.profileDefaultUserName
                      : name,
                  email: email,
                ),
                const SizedBox(height: 18),
                if (desktop)
                  ProfileDesktopSections(
                    themeModeController: themeModeController,
                    localeController: localeController,
                    displayName: name,
                    onEditName: () => _editName(context),
                    onOpenMfa: () => _openMfaSettings(context),
                    onOpenCompanion: () => _openCompanion(context),
                    onOpenLanguage: () => _openLanguage(context),
                    onSignOut:
                        signOut == null ? null : () => _confirmSignOut(context),
                    onDeleteAccount: () => _confirmDeleteAccount(context),
                  )
                else
                  ProfileCompactSections(
                    themeModeController: themeModeController,
                    localeController: localeController,
                    displayName: name,
                    onEditName: () => _editName(context),
                    onOpenMfa: () => _openMfaSettings(context),
                    onOpenCompanion: () => _openCompanion(context),
                    onOpenAppearance: () => _openAppearance(context),
                    onOpenLanguage: () => _openLanguage(context),
                    onSignOut:
                        signOut == null ? null : () => _confirmSignOut(context),
                    onDeleteAccount: () => _confirmDeleteAccount(context),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
