import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart'
    show ChatState;
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/presentation/widgets/attachment_source_sheet.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_input_bar.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/theme/clarity_colors.dart';

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
      setState(() {
        _attachment = null;
        _attachmentPreviewBytes = null;
        _attachmentName = null;
        _attachmentSize = null;
        _attachmentError = null;
      });
      if (voiceWasActive && response.trim().isNotEmpty) {
        await voiceController.speakTypedAssistantResponse(response);
      }
      return;
    }

    _messageController.text = message;
    _messageController.selection = TextSelection.collapsed(
      offset: message.length,
    );

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
    final source = await showModalBottomSheet<ChatAttachmentSource>(
      context: context,
      backgroundColor: context.clarityColors.surfaceElevated,
      showDragHandle: false,
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

    final attachment = file.path != null
        ? XFile(file.path!, name: file.name, length: file.size)
        : XFile.fromData(
            bytes!,
            name: file.name,
            length: file.size,
            path: file.name,
          );
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
      } else if (attachment.path.trim().isEmpty) {
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
                  tooltip: voiceCall.isCallActive
                      ? l10n.chatPageShowVoiceCallTooltip
                      : l10n.chatPageCallRexTooltip,
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
              ),
            ),
            if (!voiceCall.isIdle)
              InlineVoiceCallPanel(
                state: voiceCall,
                onRetry: _startVoiceCall,
                onEnd: voiceController.endCall,
                onToggleMute: voiceController.toggleMuted,
                onOpenSettings: voiceController.openVoiceSettings,
              ),
            ChatInputBar(
              controller: _messageController,
              onSend: chat.isLoading || _attachmentError != null
                  ? null
                  : _onSendTapped,
              onPickAttachment: _pickAttachment,
              onRemoveAttachment: _removeAttachment,
              onStartVoice: _startVoiceCall,
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
