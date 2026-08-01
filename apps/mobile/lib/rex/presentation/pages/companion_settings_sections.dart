import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/profile/domain/assistant_proposal_settings.dart';
import '../../../features/profile/presentation/profile_screen_widgets.dart';
import '../../../theme/clarity_colors.dart';

/// When Rex offers to save something on its own, and what it may offer.
///
/// This gate is about volunteering only. Off keeps Rex quiet unless asked; it
/// never makes Rex refuse a save the user asked for out loud.
final class CompanionSavesSection extends StatelessWidget {
  const CompanionSavesSection({
    super.key,
    required this.settings,
    required this.loading,
    required this.onChanged,
  });

  final AssistantProposalSettings settings;
  final bool loading;
  final ValueChanged<AssistantProposalSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return ProfileActionGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.assistantCompanionSettingsSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<AssistantProposalMode>(
                showSelectedIcon: false,
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
                    : (selection) {
                        onChanged(
                          settings.copyWith(mode: selection.first.storageValue),
                        );
                      },
              ),
              const SizedBox(height: 10),
              Text(
                _modeHint(l10n, settings),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (settings.enabled) ...[
          const Divider(height: 1),
          CompanionSwitchRow(
            icon: Icons.repeat_rounded,
            title: l10n.assistantAutoProposalsTypeThreads,
            value: settings.threads,
            onChanged: loading
                ? null
                : (on) => onChanged(settings.copyWith(threads: on)),
          ),
          CompanionSwitchRow(
            icon: Icons.flag_outlined,
            title: l10n.assistantAutoProposalsTypeGoals,
            value: settings.goals,
            onChanged: loading
                ? null
                : (on) => onChanged(settings.copyWith(goals: on)),
          ),
          CompanionSwitchRow(
            icon: Icons.psychology_outlined,
            title: l10n.assistantAutoProposalsTypeMemory,
            value: settings.memory,
            onChanged: loading
                ? null
                : (on) => onChanged(settings.copyWith(memory: on)),
          ),
        ],
      ],
    );
  }
}

String _modeHint(AppLocalizations l10n, AssistantProposalSettings settings) {
  if (settings.usesConfirmCards) return l10n.assistantAutoProposalsModeCardHint;
  if (settings.usesTextOffers) return l10n.assistantAutoProposalsModeTextHint;
  return l10n.assistantAutoProposalsModeOffHint;
}

final class CompanionSwitchRow extends StatelessWidget {
  const CompanionSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final detail = subtitle;

    return SwitchListTile.adaptive(
      contentPadding: ClarityNativeLayout.active(context)
          ? ClarityNativeLayout.listRowPadding(context)
          : const EdgeInsets.symmetric(horizontal: 14),
      secondary: Icon(icon, size: 20, color: colors.accent),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: detail == null
          ? null
          : Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.25,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}
