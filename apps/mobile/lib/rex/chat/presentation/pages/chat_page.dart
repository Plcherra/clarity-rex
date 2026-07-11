import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/features/dashboard/application/dashboard_deep_link_navigation.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart'
    show ChatState;
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/attachment_source_sheet.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_input_bar.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/presentation/assistant_chat_visible_provider.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/core/layout/clarity_adaptive_overlay.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';

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
  Uint8List? _attachmentPreviewBytes;
  String? _attachmentName;
  int? _attachmentSize;
  String? _attachmentError;
  String? _openClarityActionId;

  void _clearComposerAttachment() {
    setState(() {
      _attachment = null;
      _attachmentPreviewBytes = null;
      _attachmentName = null;
      _attachmentSize = null;
      _attachmentError = null;
    });
  }

  void _maybeShowClarityActionDialog(List<ClarityActionCard> pending) {
    if (!mounted || pending.isEmpty) {
      return;
    }
    final action = pending.first;
    if (_openClarityActionId == action.id) {
      return;
    }
    _openClarityActionId = action.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _openClarityActionId != action.id) {
        return;
      }
      await showClarityActionConfirmationDialog(
        context,
        action: action,
        onConfirm: (confirmed) {
          ref.read(chatProvider.notifier).executeClarityAction(confirmed);
        },
        onDismiss: (dismissed) {
          ref.read(chatProvider.notifier).dismissClarityAction(dismissed);
        },
      );
      if (mounted) {
        _openClarityActionId = null;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(assistantChatVisibleProvider.notifier).setVisible(true);
    });
    ref.listenManual<ChatState>(chatProvider, (previous, next) {
      final previousLength = previous?.messages.length ?? 0;
      final previousLast = previous?.messages.isNotEmpty == true
          ? previous!.messages.last
          : null;
      final nextLast = next.messages.isNotEmpty ? next.messages.last : null;
      final voiceMessageChanged =
          previousLast?.id != nextLast?.id ||
          previousLast?.content != nextLast?.content ||
          previousLast?.isVoiceInterim != nextLast?.isVoiceInterim;
      final shouldScroll =
          next.messages.length != previousLength ||
          voiceMessageChanged ||
          next.isLoading != (previous?.isLoading ?? false) ||
          next.errorMessage != previous?.errorMessage;
      if (shouldScroll) {
        _scrollToBottom();
      }

      final pending = pendingClarityActions(next.messages);
      final previousPending = previous == null
          ? const <ClarityActionCard>[]
          : pendingClarityActions(previous.messages);
      if (pending.isNotEmpty &&
          (previousPending.isEmpty ||
              pending.first.id !=
                  (previousPending.isEmpty ? null : previousPending.first.id))) {
        _maybeShowClarityActionDialog(pending);
      }
    });
    ref.listenManual<VoiceCallState>(voiceCallProvider, (previous, next) {
      if ((previous?.currentTranscript ?? '') != next.currentTranscript ||
          previous?.phase != next.phase) {
        _scrollToBottom();
      }

      if ((previous?.listeningReadySignal ?? 0) != next.listeningReadySignal &&
          next.phase == VoiceCallPhase.listening &&
          !next.isMuted) {
        _signalVoicePhase(next.phase, isReadyToSpeak: true);
        return;
      }

      final previousPhase = previous?.phase;
      if (previousPhase == next.phase || next.isMuted) {
        return;
      }
      if (next.phase == VoiceCallPhase.thinking ||
          next.phase == VoiceCallPhase.speaking) {
        _signalVoicePhase(next.phase);
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
    if (message.trim().isEmpty && _attachment == null) {
      return;
    }

    final attachment = _attachment;
    final voiceController = ref.read(voiceCallProvider.notifier);
    final voiceWasActive = ref.read(voiceCallProvider).isCallActive;

    _messageController.clear();
    _clearComposerAttachment();

    if (voiceWasActive) {
      final voiceLabel = message.trim().isEmpty && attachment != null
          ? context.l10n.chatPageSendingImage
          : message;
      voiceController.beginTypedTextTurn(voiceLabel);
    }

    final response = await ref
        .read(chatProvider.notifier)
        .sendMessageForAssistantResponse(message, attachment: attachment);
    final sent = response != null;
    if (!mounted) {
      return;
    }

    if (sent) {
      if (voiceWasActive && response.trim().isNotEmpty) {
        await voiceController.speakTypedAssistantResponse(response);
      }
      return;
    }

    _messageController.text = message;
    _messageController.selection = TextSelection.collapsed(
      offset: message.length,
    );
    if (attachment != null) {
      setState(() {
        _attachment = attachment;
        _attachmentName = chatAttachmentName(attachment);
      });
    }

    final errorMessage =
        ref.read(chatProvider).errorMessage ?? context.l10n.chatPageSendFailed;
    if (attachment != null) {
      setState(() => _attachmentError = errorMessage);
    }
    if (voiceWasActive) {
      voiceController.resumeListening();
    }
    _showSnackBar(errorMessage);
  }

  Future<void> _pickAttachment() async {
    if (AppCapabilities.instance.isWeb) {
      await _pickFileAttachment();
      return;
    }

    final source = await showClarityAdaptiveOverlay<ChatAttachmentSource>(
      context: context,
      backgroundColor: context.clarityColors.surfaceElevated,
      dialogMaxWidth: 420,
      dialogMaxHeight: 360,
      builder: (_) => const AttachmentSourceSheet(),
    );
    if (!mounted || source == null) {
      return;
    }

    switch (source) {
      case ChatAttachmentSource.gallery:
        await _pickImageAttachment(ImageSource.gallery);
      case ChatAttachmentSource.camera:
        await _pickImageAttachment(ImageSource.camera);
      case ChatAttachmentSource.files:
        await _pickFileAttachment();
    }
  }

  Future<void> _pickImageAttachment(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (!mounted || image == null) {
      return;
    }

    await _setPickedAttachment(image);
  }

  Future<void> _pickFileAttachment() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedChatAttachmentExtensions.toList(
        growable: false,
      ),
    );
    if (!mounted || file == null) {
      return;
    }

    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object {
      bytes = null;
    }
    if (!mounted) return;

    if (file.path == null && bytes == null) {
      setState(() {
        _attachment = null;
        _attachmentPreviewBytes = null;
        _attachmentName = file.name;
        _attachmentSize = file.size;
        _attachmentError = context.l10n.chatPageReadFileFailed;
      });
      _showSnackBar(context.l10n.chatPageReadFileFailed);
      return;
    }

    final attachment = bytes != null
        ? XFile.fromData(
            bytes,
            name: file.name,
            length: file.size,
            mimeType: chatAttachmentContentType(file.name),
            path: file.name,
          )
        : XFile(file.path!, name: file.name, length: file.size);
    await _setPickedAttachment(attachment, bytes: bytes);
  }

  Future<void> _setPickedAttachment(
    XFile attachment, {
    Uint8List? bytes,
  }) async {
    final fileName = chatAttachmentName(attachment);
    int fileSize;
    try {
      fileSize = await attachment.length();
    } on Object {
      fileSize = bytes?.length ?? 0;
    }

    final l10n = context.l10n;
    final validationError = bytes == null
        ? validateChatAttachment(
            l10n: l10n,
            fileName: fileName,
            fileSize: fileSize,
          )
        : validateChatAttachmentBytes(
            l10n: l10n,
            fileName: fileName,
            fileSize: fileSize,
            bytes: bytes,
          );
    if (validationError != null) {
      setState(() {
        _attachment = null;
        _attachmentPreviewBytes = null;
        _attachmentName = fileName;
        _attachmentSize = fileSize;
        _attachmentError = validationError;
      });
      _showSnackBar(validationError);
      return;
    }

    Uint8List? previewBytes;
    if (isChatImageAttachmentName(fileName)) {
      if (bytes != null) {
        previewBytes = bytes;
      } else {
        try {
          previewBytes = Uint8List.fromList(await attachment.readAsBytes());
        } on Object {
          previewBytes = null;
        }
      }
    }

    setState(() {
      _attachment = attachment;
      _attachmentPreviewBytes = previewBytes;
      _attachmentName = fileName;
      _attachmentSize = fileSize;
      _attachmentError = null;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachment = null;
      _attachmentPreviewBytes = null;
      _attachmentName = null;
      _attachmentSize = null;
      _attachmentError = null;
    });
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
          ref.read(voiceCallProvider).errorMessage ??
          context.l10n.chatPageStartVoiceFailed;
      _showSnackBar(error);
      return;
    }
    _scrollToBottom();
  }

  Future<void> _openVoiceMicSettings() async {
    if (AppCapabilities.instance.isWeb) {
      _showSnackBar(context.l10n.voiceErrorMicBrowserSettings);
      return;
    }
    await ref.read(voiceCallProvider.notifier).openVoiceSettings();
  }

  void _signalVoicePhase(VoiceCallPhase phase, {bool isReadyToSpeak = false}) {
    switch (phase) {
      case VoiceCallPhase.listening:
        HapticFeedback.mediumImpact();
        if (isReadyToSpeak) {
          SystemSound.play(SystemSoundType.alert);
        }
        break;
      case VoiceCallPhase.thinking:
        HapticFeedback.selectionClick();
        break;
      case VoiceCallPhase.speaking:
        HapticFeedback.lightImpact();
        break;
      case VoiceCallPhase.idle:
      case VoiceCallPhase.failed:
        break;
    }
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
    final currentConversation = ref.watch(currentConversationProvider);
    final l10n = context.l10n;
    final voiceSupported = AppCapabilities.instance.supportsAnyVoice;
    final isWeb = AppCapabilities.instance.isWeb;
    final voiceTooltip = !voiceSupported
        ? l10n.voiceWebUnavailableMessage
        : voiceCall.isCallActive
        ? (isWeb
            ? l10n.voiceWebForegroundOnlyHint
            : l10n.chatPageShowVoiceCallTooltip)
        : (isWeb
            ? l10n.chatInputVoiceWebTooltip
            : l10n.chatInputStartVoiceModeTooltip);

    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(currentConversation?.title ?? l10n.chatPageDefaultTitle),
              actions: [
                IconButton(
                  onPressed: _startVoiceCall,
                  icon: Icon(
                    voiceCall.isCallActive
                        ? Icons.graphic_eq_rounded
                        : Icons.call_rounded,
                  ),
                  tooltip: voiceTooltip,
                ),
              ],
            )
          : null,
      resizeToAvoidBottomInset: true,
      // Top inset: AssistantScreen / AppBar. Bottom inset: ChatInputBar only
      // (avoids double home-indicator padding on notched iPhones).
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ChatTranscript(
                messages: chat.messages,
                errorMessage: chat.errorMessage,
                scrollController: _scrollController,
                voiceState: voiceCall.isIdle ? null : voiceCall,
                onPromptSelected: (prompt) {
                  _messageController.text = prompt;
                  _messageController.selection = TextSelection.collapsed(
                    offset: prompt.length,
                  );
                },
                onConfirmClarityAction: (action) => ref
                    .read(chatProvider.notifier)
                    .executeClarityAction(action),
                onDismissClarityAction: (action) => ref
                    .read(chatProvider.notifier)
                    .dismissClarityAction(action),
                onDashboardLinkTap: (anchor) => ref
                    .read(dashboardDeepLinkRequestProvider.notifier)
                    .request(anchor),
              ),
            ),
            if (voiceSupported && !voiceCall.isIdle)
              InlineVoiceCallPanel(
                state: voiceCall,
                onRetry: _startVoiceCall,
                onEnd: () async => voiceController.endCall(),
                onToggleMute: voiceController.toggleMuted,
                onOpenSettings: _openVoiceMicSettings,
              ),
            ChatInputBar(
              controller: _messageController,
              onSend: chat.isLoading || _attachmentError != null
                  ? null
                  : _onSendTapped,
              onPickAttachment: _pickAttachment,
              onRemoveAttachment: _removeAttachment,
              onStartVoice: _startVoiceCall,
              voiceTooltip: voiceTooltip,
              isVoiceCallActive: voiceCall.isCallActive,
              attachment: _attachment,
              attachmentPreviewBytes: _attachmentPreviewBytes,
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
