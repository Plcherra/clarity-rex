import 'package:flutter/material.dart';

import '../../../core/layout/clarity_adaptive_overlay.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../features/profile/application/profile_controller.dart';
import '../../../features/profile/domain/assistant_proposal_settings.dart';
import '../../../theme/clarity_colors.dart';
import '../../../theme/clarity_sheet_insets.dart';

Future<void> showAssistantProposalSettingsSheet({
  required BuildContext context,
  required ProfileController profileController,
}) {
  return showClarityAdaptiveOverlay<void>(
    context: context,
    isScrollControlled: true,
    dialogMaxWidth: 520,
    dialogMaxHeight: 640,
    builder: (sheetContext) {
      return AssistantProposalSettingsSheet(
        profileController: profileController,
      );
    },
  );
}

final class AssistantProposalSettingsSheet extends StatefulWidget {
  const AssistantProposalSettingsSheet({
    super.key,
    required this.profileController,
  });

  final ProfileController profileController;

  @override
  State<AssistantProposalSettingsSheet> createState() =>
      _AssistantProposalSettingsSheetState();
}

class _AssistantProposalSettingsSheetState
    extends State<AssistantProposalSettingsSheet> {
  Future<void> _save(AssistantProposalSettings settings) async {
    try {
      await widget.profileController.updateAssistantProposalSettings(settings);
    } on Object {
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.profileController.errorMessage ?? l10n.profileUpdateFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return ListenableBuilder(
      listenable: widget.profileController,
      builder: (context, _) {
        final settings =
            widget.profileController.profile?.assistantSettings ??
            const AssistantProposalSettings();
        final loading = widget.profileController.isLoading;

        return Padding(
          padding: claritySheetPadding(context, top: 4),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.assistantCompanionSettingsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.assistantCompanionSettingsSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.assistantFinanceEditsEnabledLabel),
                  subtitle: Text(l10n.assistantFinanceEditsEnabledSubtitle),
                  value: settings.financeEditsEnabled,
                  onChanged: loading
                      ? null
                      : (enabled) async {
                          await _save(
                            settings.copyWith(financeEditsEnabled: enabled),
                          );
                        },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.assistantAutoProposalsModeLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<AssistantProposalMode>(
                  segments: [
                    ButtonSegment(
                      value: AssistantProposalMode.off,
                      label: Text(l10n.assistantAutoProposalsModeOff),
                    ),
                    ButtonSegment(
                      value: AssistantProposalMode.text,
                      label: Text(l10n.assistantAutoProposalsModeText),
                    ),
                    ButtonSegment(
                      value: AssistantProposalMode.card,
                      label: Text(l10n.assistantAutoProposalsModeCard),
                    ),
                  ],
                  selected: {AssistantProposalModeValue.fromStorage(settings.mode)},
                  onSelectionChanged: loading
                      ? null
                      : (selection) async {
                          final mode = selection.first;
                          await _save(settings.copyWith(mode: mode.storageValue));
                        },
                ),
                const SizedBox(height: 10),
                Text(
                  settings.usesConfirmCards
                      ? l10n.assistantAutoProposalsModeCardHint
                      : settings.usesTextOffers
                      ? l10n.assistantAutoProposalsModeTextHint
                      : l10n.assistantCompanionSettingsSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                if (settings.enabled) ...[
                  const SizedBox(height: 20),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.assistantAutoProposalsTypeThreads),
                    value: settings.threads,
                    onChanged: loading
                        ? null
                        : (enabled) async {
                            await _save(settings.copyWith(threads: enabled));
                          },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.assistantAutoProposalsTypeGoals),
                    value: settings.goals,
                    onChanged: loading
                        ? null
                        : (enabled) async {
                            await _save(settings.copyWith(goals: enabled));
                          },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.assistantAutoProposalsTypeMemory),
                    value: settings.memory,
                    onChanged: loading
                        ? null
                        : (enabled) async {
                            await _save(settings.copyWith(memory: enabled));
                          },
                  ),
                ],
              ],
            ),
          );
        },
      );
  }
}