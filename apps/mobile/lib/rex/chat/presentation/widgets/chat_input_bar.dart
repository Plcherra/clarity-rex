import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_attachment_image.dart';
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
                  child: _AttachmentPreview(
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
                    child: RexUiTokens.usesFilledComposerField(context)
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceElevated.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(
                                RexUiTokens.radiusPill,
                              ),
                              border: Border.all(
                                color: colors.border.withValues(alpha: 0.45),
                              ),
                            ),
                            child: _composerTextField(
                              context,
                              theme: theme,
                              colors: colors,
                              l10n: l10n,
                            ),
                          )
                        : _composerTextField(
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
    return TextField(
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

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.previewBytes,
    required this.fileName,
    required this.fileSize,
    required this.errorMessage,
    required this.onRemove,
  });

  final XFile? attachment;
  final Uint8List? previewBytes;
  final String? fileName;
  final int? fileSize;
  final String? errorMessage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final hasError = errorMessage != null;
    final title = fileName ?? l10n.commonAttachment;
    final isImage = !hasError && _isImageAttachment(title, attachment, previewBytes);
    final subtitle = hasError
        ? errorMessage!
        : fileSize == null
        ? null
        : formatAttachmentSize(fileSize!);

    if (isImage) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 112),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
                  child: _ImagePreview(
                    attachment: attachment,
                    previewBytes: previewBytes,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _RemoveAttachmentButton(onRemove: onRemove),
                ),
                if (subtitle != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius:
                            BorderRadius.circular(RexUiTokens.radiusPill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hasError
              ? colors.danger.withValues(alpha: 0.12)
              : colors.background.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
          border: Border.all(
            color: hasError
                ? colors.danger.withValues(alpha: 0.32)
                : colors.divider,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : Icons.description_outlined,
                color: hasError ? colors.danger : colors.textSecondary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasError ? colors.danger : colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                tooltip: l10n.chatInputRemoveAttachmentTooltip,
                style: IconButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  disabledForegroundColor: colors.textMuted.withValues(
                    alpha: 0.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isImageAttachment(
    String title,
    XFile? attachment,
    Uint8List? previewBytes,
  ) {
    if (previewBytes != null && previewBytes.isNotEmpty) {
      return true;
    }
    if (isChatImageAttachmentName(title)) {
      return true;
    }
    final path = attachment?.path.trim() ?? '';
    return path.isNotEmpty && isChatImageAttachmentName(path);
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.attachment,
    required this.previewBytes,
  });

  final XFile? attachment;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = previewBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ChatAttachmentImage(
        previewBytes: bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        maxHeight: 112,
      );
    }

    final path = attachment?.path.trim() ?? '';
    if (path.isNotEmpty) {
      return ChatAttachmentImage(
        localPath: path,
        fit: BoxFit.contain,
        width: double.infinity,
        maxHeight: 112,
      );
    }

    return const SizedBox(
      height: 96,
      child: Center(child: Icon(Icons.image_outlined)),
    );
  }
}

class _RemoveAttachmentButton extends StatelessWidget {
  const _RemoveAttachmentButton({required this.onRemove});

  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.56),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onRemove,
        customBorder: const CircleBorder(),
        child: const SizedBox.square(
          dimension: 28,
          child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
