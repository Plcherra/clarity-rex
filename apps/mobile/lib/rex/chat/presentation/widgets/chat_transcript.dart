import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/theme/clarity_colors.dart';

class ChatTranscript extends StatelessWidget {
  const ChatTranscript({
    super.key,
    required this.messages,
    required this.errorMessage,
    required this.scrollController,
    required this.onPromptSelected,
    required this.onConfirmClarityAction,
    required this.onDismissClarityAction,
    this.voiceState,
  });

  final List<ChatMessage> messages;
  final String? errorMessage;
  final ScrollController scrollController;
  final ValueChanged<String> onPromptSelected;
  final ValueChanged<ClarityActionCard> onConfirmClarityAction;
  final ValueChanged<ClarityActionCard> onDismissClarityAction;
  final VoiceCallState? voiceState;

  static String welcomeMessage(AppLocalizations l10n) =>
      l10n.chatTranscriptWelcomeMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMessages = messages.isNotEmpty;
    final showVoiceTranscript =
        voiceState != null && !voiceState!.isIdle;
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
              baseBottomPadding,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!hasMessages)
                  _EmptyChatState(
                    welcomeMessage: welcomeMessage(l10n),
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
                        attachmentLocalPath: message.attachmentLocalPath,
                        attachmentPreviewBytes: message.attachmentPreviewBytes,
                        attachmentName: message.attachmentName,
                        clarityActions: message.clarityActions,
                        onConfirmClarityAction: onConfirmClarityAction,
                        onDismissClarityAction: onDismissClarityAction,
                        suppressClarityActions: true,
                      ),
                    ),
                  ),
                if (showVoiceTranscript)
                  VoiceLiveTranscript(state: voiceState!),
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

  static List<String> prompts(AppLocalizations l10n) => [
    l10n.chatTranscriptPromptRemember,
    l10n.chatTranscriptPromptThinkTonight,
    l10n.chatTranscriptPromptCheckKnows,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).height < 650;

    return Padding(
      padding: EdgeInsets.fromLTRB(2, compact ? 12 : 34, 2, 14),
      child: Padding(
        padding: EdgeInsets.all(compact ? RexUiTokens.space12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chatTranscriptReadyTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: RexUiTokens.space8),
              Text(
                welcomeMessage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: compact ? RexUiTokens.space12 : 18),
            Wrap(
              spacing: RexUiTokens.space8,
              runSpacing: RexUiTokens.space8,
              children: prompts(l10n)
                  .map(
                    (prompt) => ActionChip(
                      label: Text(prompt),
                      onPressed: () => onPromptSelected(prompt),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: colors.borderActive),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RexUiTokens.radiusPill,
                        ),
                      ),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
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
    final colors = context.clarityColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colors.danger,
              size: 18,
            ),
            const SizedBox(width: RexUiTokens.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
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
