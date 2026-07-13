import 'dart:async';

import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/rex/voice/presentation/voice_elapsed_format.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_diamond_loader.dart';

class ChatTranscript extends StatelessWidget {
  const ChatTranscript({
    super.key,
    required this.messages,
    required this.errorMessage,
    required this.scrollController,
    required this.onPromptSelected,
    required this.onConfirmClarityAction,
    required this.onDismissClarityAction,
    this.onDashboardLinkTap,
    this.voiceState,
  });

  final List<ChatMessage> messages;
  final String? errorMessage;
  final ScrollController scrollController;
  final ValueChanged<String> onPromptSelected;
  final ValueChanged<ClarityActionCard> onConfirmClarityAction;
  final ValueChanged<ClarityActionCard> onDismissClarityAction;
  final ValueChanged<DashboardInsightAnchor>? onDashboardLinkTap;
  final VoiceCallState? voiceState;

  static String welcomeMessage(AppLocalizations l10n) =>
      l10n.chatTranscriptWelcomeMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMessages = messages.isNotEmpty;
    final showVoiceTranscript =
        voiceState != null && !voiceState!.isIdle;
    // Text + voice: pending durable writes must stay visible above the composer.
    final pendingActions = pendingClarityActions(messages);
    final baseBottomPadding = MediaQuery.viewInsetsOf(context).bottom > 0
        ? RexUiTokens.space12
        : RexUiTokens.space24;
    final transcriptPadH = RexUiTokens.transcriptPaddingHOf(context);

    final scrollView = CustomScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              transcriptPadH,
              RexUiTokens.space8,
              transcriptPadH,
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
                  ...messages.asMap().entries.map(
                    (entry) {
                      final message = entry.value;
                      final showVoiceProcessing =
                          voiceState != null &&
                          _shouldShowVoiceProcessingIndicator(
                            voiceState: voiceState!,
                            messages: messages,
                            messageIndex: entry.key,
                          );
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: RexUiTokens.messageGap,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ChatMessageBubble(
                              text: message.content,
                              isUser: message.role == ChatMessageRole.user,
                              isStreaming: message.isStreaming,
                              isVoiceInterim: message.isVoiceInterim,
                              attachmentLocalPath: message.attachmentLocalPath,
                              attachmentPreviewBytes:
                                  message.attachmentPreviewBytes,
                              attachmentName: message.attachmentName,
                              clarityActions: message.clarityActions,
                              onConfirmClarityAction: onConfirmClarityAction,
                              onDismissClarityAction: onDismissClarityAction,
                              suppressClarityActions: true,
                              dashboardLinkAnchor: message.dashboardLinkAnchor,
                              onDashboardLinkTap:
                                  message.dashboardLinkAnchor == null ||
                                      onDashboardLinkTap == null
                                  ? null
                                  : () => onDashboardLinkTap!(
                                      message.dashboardLinkAnchor!,
                                    ),
                            ),
                            if (showVoiceProcessing)
                              _VoiceProcessingIndicator(
                                voiceState: voiceState!,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                if (pendingActions.isNotEmpty) ...[
                  ClarityActionCardsStrip(
                    actions: pendingActions,
                    onConfirm: onConfirmClarityAction,
                    onDismiss: onDismissClarityAction,
                  ),
                  const SizedBox(height: RexUiTokens.confirmCardGap),
                ],
                if (showVoiceTranscript)
                  VoiceLiveTranscript(state: voiceState!),
                if (errorMessage != null) ...[
                  const SizedBox(height: RexUiTokens.space8),
                  _ChatErrorBanner(message: errorMessage!),
                ],
                const SizedBox(height: RexUiTokens.space8),
              ]),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ],
    );

    if (!RexUiTokens.showsTranscriptScrollbar(context)) {
      return scrollView;
    }
    return Scrollbar(
      controller: scrollController,
      child: scrollView,
    );
  }
}

int? _lastFinalizedVoiceUserIndex(List<ChatMessage> messages) {
  for (var index = messages.length - 1; index >= 0; index--) {
    final message = messages[index];
    if (message.role == ChatMessageRole.user && !message.isVoiceInterim) {
      return index;
    }
  }
  return null;
}

bool _shouldShowVoiceProcessingIndicator({
  required VoiceCallState voiceState,
  required List<ChatMessage> messages,
  required int messageIndex,
}) {
  final userIndex = _lastFinalizedVoiceUserIndex(messages);
  if (userIndex == null || messageIndex != userIndex) {
    return false;
  }

  if (voiceState.phase == VoiceCallPhase.thinking) {
    return true;
  }

  final thoughtDuration = voiceState.lastThoughtDuration;
  if (thoughtDuration == null || thoughtDuration <= Duration.zero) {
    return false;
  }

  if (voiceState.phase == VoiceCallPhase.speaking) {
    return true;
  }

  return voiceState.phase == VoiceCallPhase.listening &&
      messages.isNotEmpty &&
      messages.last.role == ChatMessageRole.assistant &&
      !voiceState.isCapturingSpeech;
}

class _VoiceProcessingIndicator extends StatefulWidget {
  const _VoiceProcessingIndicator({required this.voiceState});

  final VoiceCallState voiceState;

  @override
  State<_VoiceProcessingIndicator> createState() =>
      _VoiceProcessingIndicatorState();
}

class _VoiceProcessingIndicatorState extends State<_VoiceProcessingIndicator> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final isThinking = widget.voiceState.phase == VoiceCallPhase.thinking;
    final elapsed = isThinking
        ? formatVoiceElapsed(widget.voiceState.thinkingElapsed())
        : formatVoiceElapsed(widget.voiceState.lastThoughtDuration ?? Duration.zero);
    final label = isThinking
        ? l10n.voicePanelThinkingElapsed(elapsed)
        : l10n.voicePanelThoughtFor(elapsed);

    return Padding(
      padding: EdgeInsets.only(
        top: RexUiTokens.space2,
        left: RexUiTokens.bubbleSideInsetOf(context),
      ),
      child: Row(
        children: [
          if (isThinking) ...[
            ClarityDiamondLoader(size: 14),
            const SizedBox(width: RexUiTokens.space8),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
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
