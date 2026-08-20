import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_service.dart';
import 'package:clarity/rex/chat/application/chat_linked_accounts.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';

/// [ChatTranscript] that reads linked-account presence from the read model.
class AccountsAwareChatTranscript extends ConsumerWidget {
  const AccountsAwareChatTranscript({
    super.key,
    required this.messages,
    required this.errorMessage,
    required this.scrollController,
    required this.onPromptSelected,
    required this.onConfirmClarityAction,
    required this.onDismissClarityAction,
    this.onDashboardLinkTap,
    this.voiceState,
    this.focusMessageId,
    this.focusHighlightTerms = const [],
    this.onFocusConsumed,
  });

  final List<ChatMessage> messages;
  final String? errorMessage;
  final ScrollController scrollController;
  final ValueChanged<String> onPromptSelected;
  final ValueChanged<ClarityActionCard> onConfirmClarityAction;
  final ValueChanged<ClarityActionCard> onDismissClarityAction;
  final ValueChanged<DashboardInsightAnchor>? onDashboardLinkTap;
  final VoiceCallState? voiceState;
  final String? focusMessageId;
  final List<String> focusHighlightTerms;
  final VoidCallback? onFocusConsumed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatFinancePrefetchProvider);
    final service = ref.watch(assistantFinancialContextServiceProvider);
    final hasLinkedAccounts =
        service?.hasCachedLinkedAccounts == true ||
        (ref.watch(hasLinkedAccountsProvider).value ?? false);
    return ChatTranscript(
      messages: messages,
      errorMessage: errorMessage,
      scrollController: scrollController,
      onPromptSelected: onPromptSelected,
      onConfirmClarityAction: onConfirmClarityAction,
      onDismissClarityAction: onDismissClarityAction,
      onDashboardLinkTap: onDashboardLinkTap,
      voiceState: voiceState,
      focusMessageId: focusMessageId,
      focusHighlightTerms: focusHighlightTerms,
      onFocusConsumed: onFocusConsumed,
      hasLinkedAccounts: hasLinkedAccounts,
    );
  }
}
