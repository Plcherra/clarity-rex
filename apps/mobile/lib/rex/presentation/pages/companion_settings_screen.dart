import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/clarity_breakpoints.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../features/profile/application/profile_controller.dart';
import '../../../features/profile/domain/assistant_proposal_settings.dart';
import '../../../features/profile/presentation/profile_screen_widgets.dart';
import '../../../features/profile/presentation/usage_summary_screen.dart';
import 'companion_settings_sections.dart';

/// Everything about how Rex behaves, on one page.
///
/// These settings used to be a sheet reachable only from the gear above the
/// assistant tabs, with the related ones scattered through Profile. A sheet is
/// for a single decision; this is a place to look around in.
Future<void> openCompanionSettings(
  BuildContext context, {
  required ProfileController profileController,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) =>
          CompanionSettingsScreen(profileController: profileController),
    ),
  );
}

final class CompanionSettingsScreen extends StatelessWidget {
  const CompanionSettingsScreen({super.key, required this.profileController});

  final ProfileController profileController;

  Future<void> _save(
    BuildContext context,
    AssistantProposalSettings settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedCopy = context.l10n.profileUpdateFailed;
    try {
      await profileController.updateAssistantProposalSettings(settings);
    } on Object {
      messenger.showSnackBar(
        SnackBar(
          content: Text(profileController.errorMessage ?? failedCopy),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.companionScreenTitle),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Scrollbar(
        thumbVisibility: isClarityDesktopLayout(context),
        child: ListenableBuilder(
          listenable: profileController,
          builder: (context, _) {
            final profile = profileController.profile;
            final settings =
                profile?.assistantSettings ?? const AssistantProposalSettings();
            final loading = profileController.isLoading;

            return ListView(
              padding: ClarityNativeLayout.active(context)
                  ? ClarityNativeLayout.pagePadding(context, top: 8, bottom: 28)
                  : const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                ProfileSectionLabel(l10n.assistantAutoProposalsModeLabel),
                const SizedBox(height: 8),
                CompanionSavesSection(
                  settings: settings,
                  loading: loading,
                  onChanged: (next) => _save(context, next),
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
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const UsageSummaryScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
