import 'package:flutter/material.dart';

import '../../core/l10n/app_l10n.dart';
import '../../l10n/app_localizations.dart';
import 'rex_ui_tokens.dart';

/// Assistant sub-tabs. [chats] is compact-only (phone has no sidebar list).
enum AssistantTab { chats, chat, memory, goals, overview }

extension AssistantTabContract on AssistantTab {
  String get id {
    return switch (this) {
      AssistantTab.chats => 'chats',
      AssistantTab.chat => 'chat',
      AssistantTab.memory => 'memory',
      AssistantTab.goals => 'goals',
      AssistantTab.overview => 'overview',
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      AssistantTab.chats => l10n.assistantTabChats,
      AssistantTab.chat => l10n.assistantTabChat,
      AssistantTab.memory => l10n.assistantTabKnows,
      AssistantTab.goals => l10n.assistantTabGoals,
      AssistantTab.overview => l10n.assistantTabOverview,
    };
  }

  IconData get icon {
    return switch (this) {
      AssistantTab.chats => Icons.forum_outlined,
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

/// Compact phone: Chats | Chat | Knows | Goals | Overview.
/// Wide `/app/`: Chat | Knows | Goals | Overview (list lives in sidebar).
List<AssistantTab> assistantTabsForLayout({required bool compact}) {
  if (compact) {
    return const [
      AssistantTab.chats,
      AssistantTab.chat,
      AssistantTab.memory,
      AssistantTab.goals,
      AssistantTab.overview,
    ];
  }
  return const [
    AssistantTab.chat,
    AssistantTab.memory,
    AssistantTab.goals,
    AssistantTab.overview,
  ];
}

List<AssistantTab> assistantTabsOf(BuildContext context) {
  return assistantTabsForLayout(
    compact: RexUiTokens.isCompactChrome(context),
  );
}
