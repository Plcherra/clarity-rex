import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_input_bar_attachment.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

/// Composer row: text field, optional attachment preview, and send action.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    this.onSend,
    this.onPickAttachment,
    this.onRemoveAttachment,
    this.onStartVoice,
    this.voiceTooltip,
    this.attachment,
    this.attachmentPreviewBytes,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentError,
    this.isLoading = false,
    this.isVoiceCallActive = false,
  });

  final TextEditingController controller;
  final VoidCallback? onSend;
  final VoidCallback? onPickAttachment;
  final VoidCallback? onRemoveAttachment;
  final VoidCallback? onStartVoice;
  final String? voiceTooltip;
  final XFile? attachment;
  final Uint8List? attachmentPreviewBytes;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentError;
  final bool isLoading;
  final bool isVoiceCallActive;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _composerFocusNode;

  @override
  void initState() {
    super.initState();
    _composerFocusNode = FocusNode(onKeyEvent: _handleComposerKey);
  }

  @override
  void dispose() {
    _composerFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleComposerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final hasAttachment =
        widget.attachment != null || widget.attachmentName != null;
    final canSend = _canSend(
      widget.controller.text,
      hasAttachment: hasAttachment,
      isLoading: widget.isLoading,
      hasBlockingAttachmentError: widget.attachmentError != null,
    );
    if (!canSend || widget.onSend == null) {
      return KeyEventResult.ignored;
    }
    widget.onSend!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final hasBlockingAttachmentError = widget.attachmentError != null;
    final hasAttachment =
        widget.attachment != null || widget.attachmentName != null;

    return Material(
      color: colors.background,
      child: SafeArea(
        top: false,
        // Owns bottom safe area for chat (home indicator / gesture inset).
        minimum: EdgeInsets.only(
          bottom: RexUiTokens.composerPaddingBottomOf(context),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            RexUiTokens.composerPaddingHOf(context),
            RexUiTokens.composerPaddingTopOf(context),
            RexUiTokens.composerPaddingHOf(context),
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAttachment || widget.attachmentError != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: RexUiTokens.space4,
                    right: RexUiTokens.space4,
                    bottom: RexUiTokens.space4,
                  ),
                  child: ChatInputAttachmentPreview(
                    attachment: widget.attachment,
                    previewBytes: widget.attachmentPreviewBytes,
                    fileName: widget.attachmentName,
                    fileSize: widget.attachmentSize,
                    errorMessage: widget.attachmentError,
                    onRemove: widget.isLoading ? null : widget.onRemoveAttachment,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ComposerIconButton(
                    icon: Icons.attach_file_rounded,
                    tooltip: AppCapabilities.instance.isWeb
                        ? l10n.chatInputAttachWebTooltip
                        : l10n.chatInputAttachTooltip,
                    onPressed: widget.isLoading ? null : widget.onPickAttachment,
                  ),
                  _ComposerIconButton(
                    icon: widget.isVoiceCallActive
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_rounded,
                    tooltip: widget.voiceTooltip ??
                        (widget.isVoiceCallActive
                            ? l10n.chatPageShowVoiceCallTooltip
                            : l10n.chatInputStartVoiceModeTooltip),
                    onPressed: widget.isLoading ? null : widget.onStartVoice,
                    isActive: widget.isVoiceCallActive,
                  ),
                  Expanded(
                    child: _composerTextField(
                      context,
                      theme: theme,
                      colors: colors,
                      l10n: l10n,
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, child) {
                      final canSendNow = _canSend(
                        value.text,
                        hasAttachment: hasAttachment,
                        isLoading: widget.isLoading,
                        hasBlockingAttachmentError:
                            hasBlockingAttachmentError,
                      );
                      return _ComposerIconButton(
                        icon: Icons.arrow_upward_rounded,
                        tooltip: l10n.chatInputSendTooltip,
                        onPressed: canSendNow ? widget.onSend : null,
                        isActive: canSendNow,
                        isLoading: widget.isLoading,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composerTextField(
    BuildContext context, {
    required ThemeData theme,
    required ClarityColorTokens colors,
    required AppLocalizations l10n,
  }) {
    final field = TextField(
      focusNode: _composerFocusNode,
      controller: widget.controller,
      minLines: 1,
      maxLines: 7,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: colors.accent,
      decoration: InputDecoration(
        hintText: l10n.chatInputMessageHint,
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: RexUiTokens.space8,
          vertical: RexUiTokens.composerFieldPaddingVOf(context),
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.textMuted.withValues(alpha: 0.7),
        ),
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colors.textPrimary,
        height: 1.35,
      ),
    );

    if (!ClarityNativeLayout.active(context)) {
      return field;
    }

    // Comfortable tap/type height without a filled pill (Grok / iMessage-like).
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: ClarityNativeLayout.composerFieldMinHeight(context),
      ),
      child: Align(alignment: Alignment.centerLeft, child: field),
    );
  }

  bool _canSend(
    String text, {
    required bool hasAttachment,
    required bool isLoading,
    required bool hasBlockingAttachmentError,
  }) {
    if (isLoading || hasBlockingAttachmentError) {
      return false;
    }
    return text.trim().isNotEmpty || hasAttachment;
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final enabled = onPressed != null;
    final iconSize = RexUiTokens.composerIconSizeOf(context);
    final foreground = isActive && enabled
        ? colors.accent
        : enabled
        ? colors.textPrimary
        : colors.textMuted.withValues(alpha: 0.45);
    final softFill = isActive && enabled
        ? colors.accent.withValues(alpha: 0.14)
        : Colors.transparent;

    return IconButton(
      onPressed: onPressed,
      icon: isLoading
          ? const ClarityInlineLoader(
              size: 18,
              strokeWidth: 2,
            )
          : Icon(icon, size: 22),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: Size.square(iconSize),
        fixedSize: Size.square(iconSize),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: softFill,
        foregroundColor: foreground,
        disabledForegroundColor: colors.textMuted.withValues(alpha: 0.45),
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        overlayColor: colors.textPrimary.withValues(alpha: 0.08),
      ),
    );
  }
}
