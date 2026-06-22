import 'package:flutter/material.dart';

import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

class ChatTranscript extends StatelessWidget {
  const ChatTranscript({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.errorMessage,
    required this.hasStreamingAssistant,
    required this.scrollController,
    required this.onPromptSelected,
    required this.onConfirmClarityAction,
    required this.onDismissClarityAction,
    this.bottomPadding = 0,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final bool hasStreamingAssistant;
  final ScrollController scrollController;
  final ValueChanged<String> onPromptSelected;
  final ValueChanged<ClarityActionCard> onConfirmClarityAction;
  final ValueChanged<ClarityActionCard> onDismissClarityAction;
  final double bottomPadding;

  static const _welcomeMessage =
      "I'm Rex. Tell me what's happening, what changed, or what you want me to remember.";

  @override
  Widget build(BuildContext context) {
    final hasMessages = messages.isNotEmpty;
    final baseBottomPadding = MediaQuery.viewInsetsOf(context).bottom > 0
        ? RexUiTokens.space12
        : RexUiTokens.space24;

    return Scrollbar(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              RexUiTokens.space16,
              RexUiTokens.space8,
              RexUiTokens.space16,
              baseBottomPadding + bottomPadding,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!hasMessages)
                  _EmptyChatState(
                    welcomeMessage: _welcomeMessage,
                    onPromptSelected: onPromptSelected,
                  )
                else
                  ...messages.map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChatMessageBubble(
                        text: message.content,
                        isUser: message.role == ChatMessageRole.user,
                        isStreaming: message.isStreaming,
                        clarityActions: message.clarityActions,
                        onConfirmClarityAction: onConfirmClarityAction,
                        onDismissClarityAction: onDismissClarityAction,
                      ),
                    ),
                  ),
                if (isLoading && !hasStreamingAssistant) ...[
                  const SizedBox(height: 2),
                  const ChatMessageBubble(text: '', isLoading: true),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: RexUiTokens.space12),
                  _ChatErrorBanner(message: errorMessage!),
                ],
                const SizedBox(height: RexUiTokens.space16),
              ]),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({
    required this.welcomeMessage,
    required this.onPromptSelected,
  });

  final String welcomeMessage;
  final ValueChanged<String> onPromptSelected;

  static const _prompts = [
    'What should I remember?',
    'Help me think through tonight.',
    'Check what Clarity knows.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 54, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rex',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: RexUiTokens.text,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: RexUiTokens.space8),
          Text(
            welcomeMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: RexUiTokens.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: RexUiTokens.space20),
          Wrap(
            spacing: RexUiTokens.space8,
            runSpacing: RexUiTokens.space8,
            children: _prompts
                .map(
                  (prompt) => ActionChip(
                    label: Text(prompt),
                    onPressed: () => onPromptSelected(prompt),
                    backgroundColor: RexUiTokens.surfaceSoft,
                    side: BorderSide(
                      color: RexUiTokens.border.withValues(alpha: 0.75),
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: RexUiTokens.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ChatErrorBanner extends StatelessWidget {
  const _ChatErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: RexUiTokens.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        border: Border.all(color: RexUiTokens.danger.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: RexUiTokens.danger,
              size: 18,
            ),
            const SizedBox(width: RexUiTokens.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RexUiTokens.text,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
