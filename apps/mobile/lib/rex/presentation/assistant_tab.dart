import 'package:flutter/material.dart';

import '../../core/l10n/app_l10n.dart';
import '../../l10n/app_localizations.dart';

enum AssistantTab { chat, memory, goals, overview }

extension AssistantTabContract on AssistantTab {
  String get id {
    return switch (this) {
      AssistantTab.chat => 'chat',
      AssistantTab.memory => 'memory',
      AssistantTab.goals => 'goals',
      AssistantTab.overview => 'overview',
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      AssistantTab.chat => l10n.assistantTabChat,
      AssistantTab.memory => l10n.assistantTabKnows,
      AssistantTab.goals => l10n.assistantTabGoals,
      AssistantTab.overview => l10n.assistantTabOverview,
    };
  }

  IconData get icon {
    return switch (this) {
      AssistantTab.chat => Icons.chat_bubble_outline_rounded,
      AssistantTab.memory => Icons.psychology_alt_outlined,
      AssistantTab.goals => Icons.flag_outlined,
      AssistantTab.overview => Icons.insights_outlined,
    };
  }

  String semanticLabel(AppLocalizations l10n) =>
      l10n.assistantTabSemanticLabel(label(l10n));

  Key get key => ValueKey<String>('assistant-tab-$id');
}

extension AssistantTabContext on AssistantTab {
  String labelFor(BuildContext context) => label(context.l10n);

  String semanticLabelFor(BuildContext context) =>
      semanticLabel(context.l10n);
}
