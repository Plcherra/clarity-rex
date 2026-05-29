import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:clarity/features/assistant/assistant_providers.dart';
import 'package:clarity/features/assistant/brain/rex_deep_think_state.dart';
import 'package:clarity/features/assistant/chat/application/chat_controller.dart'
    show ChatState;
import 'package:clarity/features/assistant/chat/domain/chat_attachment.dart';
import 'package:clarity/features/assistant/chat/domain/chat_message.dart';
import 'package:clarity/features/assistant/chat/presentation/widgets/chat_input_bar.dart';
import 'package:clarity/features/assistant/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';

/// Main chat surface: empty thread UI + composer.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with AutomaticKeepAliveClientMixin<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  XFile? _attachment;
  String? _attachmentName;
  int? _attachmentSize;
  String? _attachmentError;

  static const String _welcomeMessage =
      "Hi, I'm Rex. Ask about your money, plans, memory, or next decision.";

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<ChatState>(chatProvider, (previous, next) {
      final previousLength = previous?.messages.length ?? 0;
      final shouldScroll =
          next.messages.length != previousLength ||
          next.isLoading != (previous?.isLoading ?? false) ||
          next.errorMessage != previous?.errorMessage;
      if (shouldScroll) {
        _scrollToBottom();
      }
    });
    ref.listenManual<VoiceCallState>(voiceCallProvider, (previous, next) {
      if ((previous?.listeningReadySignal ?? 0) != next.listeningReadySignal &&
          next.phase == VoiceCallPhase.listening &&
          !next.isMuted) {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _onSendTapped() async {
    if (_attachmentError != null) {
      _showSnackBar(_attachmentError!);
      return;
    }

    final message = _messageController.text;
    final attachment = _attachment;
    final deepThink = ref.read(rexDeepThinkEnabledProvider);
    final sent = await ref
        .read(chatProvider.notifier)
        .sendMessage(message, attachment: attachment, deepThink: deepThink);
    if (!mounted) {
      return;
    }

    if (sent) {
      _messageController.clear();
      setState(() {
        _attachment = null;
        _attachmentName = null;
        _attachmentSize = null;
        _attachmentError = null;
      });
      ref.read(rexDeepThinkEnabledProvider.notifier).reset();
      return;
    }

    final errorMessage =
        ref.read(chatProvider).errorMessage ?? 'Could not send message.';
    if (attachment != null) {
      setState(() => _attachmentError = errorMessage);
    }
    _showSnackBar(errorMessage);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedChatAttachmentExtensions.toList(
        growable: false,
      ),
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final validationError = file.bytes == null
        ? validateChatAttachment(fileName: file.name, fileSize: file.size)
        : validateChatAttachmentBytes(
            fileName: file.name,
            fileSize: file.size,
            bytes: file.bytes!,
          );
    if (validationError != null) {
      setState(() {
        _attachment = null;
        _attachmentName = file.name;
        _attachmentSize = file.size;
        _attachmentError = validationError;
      });
      _showSnackBar(validationError);
      return;
    }
    if (file.path == null && file.bytes == null) {
      setState(() {
        _attachment = null;
        _attachmentName = file.name;
        _attachmentSize = file.size;
        _attachmentError = 'Could not read selected file.';
      });
      _showSnackBar('Could not read selected file.');
      return;
    }

    final attachment = file.path != null
        ? XFile(file.path!, name: file.name, length: file.size)
        : XFile.fromData(
            file.bytes!,
            name: file.name,
            length: file.size,
            path: file.name,
          );
    setState(() {
      _attachment = attachment;
      _attachmentName = file.name;
      _attachmentSize = file.size;
      _attachmentError = null;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachment = null;
      _attachmentName = null;
      _attachmentSize = null;
      _attachmentError = null;
    });
  }

  void _setDeepThink(bool selected) {
    ref.read(rexDeepThinkEnabledProvider.notifier).setEnabled(selected);
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendMemoryCommand(String command) async {
    await ref.read(chatProvider.notifier).sendMessage(command);
  }

  void _editMemoryCandidate(MemoryCandidateCard candidate) {
    _messageController.text = 'Edit pending memory ${candidate.id}: ';
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
  }

  Future<void> _startVoiceCall() async {
    FocusScope.of(context).unfocus();
    final voice = ref.read(voiceCallProvider);
    if (voice.isCallActive) {
      _scrollToBottom();
      return;
    }

    final started = await ref
        .read(voiceCallProvider.notifier)
        .startCall(conversationId: ref.read(chatProvider).conversationId);
    if (!mounted) {
      return;
    }
    if (!started) {
      final error =
          ref.read(voiceCallProvider).errorMessage ?? 'Could not start Rex.';
      _showSnackBar(error);
      return;
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final chat = ref.watch(chatProvider);
    final voiceCall = ref.watch(voiceCallProvider);
    final voiceController = ref.read(voiceCallProvider.notifier);
    final deepThinkEnabled = ref.watch(rexDeepThinkEnabledProvider);
    final currentConversation = ref.watch(currentConversationProvider);
    final hasMessages = chat.messages.isNotEmpty;
    final hasStreamingAssistant =
        hasMessages &&
        chat.messages.last.role == ChatMessageRole.assistant &&
        chat.messages.last.isStreaming;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(currentConversation?.title ?? 'Rex'),
              actions: [
                IconButton(
                  onPressed: voiceCall.isCallActive ? null : _startVoiceCall,
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Call Rex',
                ),
              ],
            )
          : null,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: CustomScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        MediaQuery.viewInsetsOf(context).bottom > 0 ? 12 : 24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (!hasMessages)
                            _EmptyChatState(
                              welcomeMessage: _welcomeMessage,
                              onPromptSelected: (prompt) {
                                _messageController.text = prompt;
                                _messageController.selection =
                                    TextSelection.collapsed(
                                      offset: prompt.length,
                                    );
                              },
                            )
                          else
                            ...chat.messages.map(
                              (message) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: ChatMessageBubble(
                                  text: message.content,
                                  isUser: message.role == ChatMessageRole.user,
                                  isStreaming: message.isStreaming,
                                  memoryCandidates: message.memoryCandidates,
                                  clarityActions: message.clarityActions,
                                  onApproveAllCandidates: () =>
                                      _sendMemoryCommand('approve all pending'),
                                  onRejectAllCandidates: () =>
                                      _sendMemoryCommand('reject all pending'),
                                  onApproveCandidate: (candidate) =>
                                      _sendMemoryCommand(
                                        'confirm memory candidate ${candidate.id}',
                                      ),
                                  onRejectCandidate: (candidate) =>
                                      _sendMemoryCommand(
                                        'do not save memory candidate ${candidate.id}',
                                      ),
                                  onEditCandidate: _editMemoryCandidate,
                                  onConfirmClarityAction: (action) => ref
                                      .read(chatProvider.notifier)
                                      .executeClarityAction(action),
                                  onDismissClarityAction: (action) => ref
                                      .read(chatProvider.notifier)
                                      .dismissClarityAction(action),
                                ),
                              ),
                            ),
                          if (chat.isLoading && !hasStreamingAssistant) ...[
                            const SizedBox(height: 2),
                            const ChatMessageBubble(text: '', isLoading: true),
                          ],
                          if (chat.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _ChatErrorBanner(message: chat.errorMessage!),
                          ],
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            if (!voiceCall.isIdle)
              _InlineVoiceCallPanel(
                state: voiceCall,
                onRetry: _startVoiceCall,
                onEnd: voiceController.endCall,
                onToggleMute: voiceController.toggleMuted,
                onInterrupt: () => voiceController.interruptAndListen(
                  reason: 'Rex was interrupted.',
                ),
                onOpenSettings: voiceController.openVoiceSettings,
              ),
            ChatInputBar(
              controller: _messageController,
              onSend: chat.isLoading || _attachmentError != null
                  ? null
                  : _onSendTapped,
              onPickAttachment: _pickAttachment,
              onRemoveAttachment: _removeAttachment,
              onStartVoice: voiceCall.isCallActive ? null : _startVoiceCall,
              isVoiceCallActive: voiceCall.isCallActive,
              isDeepThinkEnabled: deepThinkEnabled,
              onDeepThinkChanged: chat.isLoading ? null : _setDeepThink,
              attachmentName: _attachmentName,
              attachmentSize: _attachmentSize,
              attachmentError: _attachmentError,
              isLoading: chat.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineVoiceCallPanel extends StatelessWidget {
  const _InlineVoiceCallPanel({
    required this.state,
    required this.onRetry,
    required this.onEnd,
    required this.onToggleMute,
    required this.onInterrupt,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final VoidCallback onRetry;
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;
  final VoidCallback onInterrupt;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFailed = state.phase == VoiceCallPhase.failed;
    final canInterrupt =
        state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.thinking;
    final transcript = state.currentTranscript.trim();
    final error = state.errorMessage?.trim();

    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isFailed ? scheme.errorContainer : scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isFailed
                    ? scheme.error.withValues(alpha: 0.22)
                    : scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _voiceStatusIcon(state),
                        color: isFailed ? scheme.error : scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _voiceStatusLabel(state),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isFailed
                                ? scheme.onErrorContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (isFailed) ...[
                        IconButton(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_rounded),
                          tooltip: 'Open app settings',
                        ),
                        IconButton.filledTonal(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Try again',
                        ),
                      ] else ...[
                        IconButton(
                          onPressed: onToggleMute,
                          icon: Icon(
                            state.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                          ),
                          tooltip: state.isMuted ? 'Unmute mic' : 'Mute mic',
                        ),
                        IconButton(
                          onPressed: canInterrupt ? onInterrupt : null,
                          icon: const Icon(Icons.front_hand_rounded),
                          tooltip: 'Interrupt Rex',
                        ),
                      ],
                      IconButton.filled(
                        onPressed: onEnd,
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        icon: const Icon(Icons.call_end_rounded),
                        tooltip: 'End call',
                      ),
                    ],
                  ),
                  if (transcript.isNotEmpty || (isFailed && error != null)) ...[
                    const SizedBox(height: 8),
                    Text(
                      isFailed && error != null ? error : transcript,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isFailed
                            ? scheme.onErrorContainer
                            : scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _voiceStatusIcon(VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return Icons.mic_off_rounded;
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => Icons.call_rounded,
      VoiceCallPhase.listening => Icons.mic_rounded,
      VoiceCallPhase.thinking => Icons.more_horiz_rounded,
      VoiceCallPhase.speaking => Icons.volume_up_rounded,
      VoiceCallPhase.failed => Icons.error_outline_rounded,
    };
  }

  String _voiceStatusLabel(VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return 'Voice muted';
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => 'Voice ready',
      VoiceCallPhase.listening => 'Rex is listening',
      VoiceCallPhase.thinking => 'Rex is thinking',
      VoiceCallPhase.speaking => 'Rex is speaking',
      VoiceCallPhase.failed => 'Voice needs attention',
    };
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
    'Review my spending priorities.',
    'Help me choose the next financial goal.',
    'Remember how I want you to coach me.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Rex',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            welcomeMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _prompts
                .map(
                  (prompt) => ActionChip(
                    label: Text(prompt),
                    onPressed: () => onPromptSelected(prompt),
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
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: scheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
