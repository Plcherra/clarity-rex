import 'package:clarity/l10n/app_localizations.dart';

/// Empty-thread chips. Money prompts only after accounts exist so a tap/send
/// matches [shouldAttachAssistantFinancialContext] without a special case.
List<String> emptyChatPrompts(
  AppLocalizations l10n, {
  required bool hasLinkedAccounts,
}) {
  if (hasLinkedAccounts) {
    return [
      l10n.chatTranscriptPromptSpendWeek,
      l10n.chatTranscriptPromptBankBalance,
      l10n.chatTranscriptPromptAccounts,
    ];
  }
  return [
    l10n.chatTranscriptPromptRemember,
    l10n.chatTranscriptPromptThinkTonight,
    l10n.chatTranscriptPromptCheckKnows,
  ];
}
