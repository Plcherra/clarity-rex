import 'package:flutter/material.dart';

import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

/// Composer row: text field, optional attachment preview, and send action.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    this.onSend,
    this.onPickAttachment,
    this.onRemoveAttachment,
    this.onStartVoice,
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
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentError;
  final bool isLoading;
  final bool isVoiceCallActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBlockingAttachmentError = attachmentError != null;

    return Material(
      color: RexUiTokens.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RexUiTokens.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge),
              border: Border.all(
                color: RexUiTokens.border.withValues(alpha: 0.8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attachmentName != null || attachmentError != null)
                    _AttachmentPreview(
                      fileName: attachmentName,
                      fileSize: attachmentSize,
                      errorMessage: attachmentError,
                      onRemove: isLoading ? null : onRemoveAttachment,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _ComposerIconButton(
                          icon: Icons.attach_file_rounded,
                          tooltip: 'Attach file or image',
                          onPressed: isLoading ? null : onPickAttachment,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _ComposerIconButton(
                          icon: isVoiceCallActive
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_rounded,
                          tooltip: isVoiceCallActive
                              ? 'Show voice call'
                              : 'Start voice mode',
                          onPressed: isLoading ? null : onStartVoice,
                          isActive: isVoiceCallActive,
                          isProminent: true,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: !isLoading,
                          minLines: 1,
                          maxLines: 7,
                          textInputAction: TextInputAction.send,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: RexUiTokens.accent,
                          onSubmitted: (_) {
                            final text = controller.text.trim();
                            if (text.isNotEmpty &&
                                !isLoading &&
                                !hasBlockingAttachmentError) {
                              onSend?.call();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Message Assistant…',
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 11,
                            ),
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: RexUiTokens.textSubtle.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: RexUiTokens.text,
                            height: 1.35,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          final hasText = value.text.trim().isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: IconButton(
                              onPressed:
                                  hasText &&
                                      !isLoading &&
                                      !hasBlockingAttachmentError
                                  ? onSend
                                  : null,
                              style: IconButton.styleFrom(
                                minimumSize: const Size.square(40),
                                fixedSize: const Size.square(40),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: RexUiTokens.accent,
                                foregroundColor: RexUiTokens.background,
                                disabledBackgroundColor: RexUiTokens
                                    .surfaceRaised
                                    .withValues(alpha: 0.7),
                                disabledForegroundColor: RexUiTokens.textSubtle
                                    .withValues(alpha: 0.55),
                              ),
                              icon: isLoading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: RexUiTokens.background,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 22,
                                    ),
                              tooltip: 'Send',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.isProminent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isProminent;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive
        ? RexUiTokens.accent
        : isProminent
        ? RexUiTokens.text
        : RexUiTokens.textMuted;
    final background = isActive
        ? RexUiTokens.accent.withValues(alpha: 0.16)
        : isProminent
        ? RexUiTokens.surfaceRaised
        : Colors.transparent;

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(38),
        fixedSize: const Size.square(38),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: RexUiTokens.textSubtle.withValues(alpha: 0.45),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.fileName,
    required this.fileSize,
    required this.errorMessage,
    required this.onRemove,
  });

  final String? fileName;
  final int? fileSize;
  final String? errorMessage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorMessage != null;
    final title = fileName ?? 'Attachment';
    final isImage = fileName != null && isChatImageAttachmentName(fileName!);
    final subtitle = hasError
        ? errorMessage!
        : fileSize == null
        ? null
        : formatAttachmentSize(fileSize!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hasError
              ? RexUiTokens.danger.withValues(alpha: 0.12)
              : RexUiTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
          border: Border.all(
            color: hasError
                ? RexUiTokens.danger.withValues(alpha: 0.42)
                : RexUiTokens.border.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : isImage
                    ? Icons.image_outlined
                    : Icons.description_outlined,
                color: hasError ? RexUiTokens.danger : RexUiTokens.textMuted,
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
                        color: RexUiTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasError
                              ? RexUiTokens.danger
                              : RexUiTokens.textSubtle,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Remove attachment',
                style: IconButton.styleFrom(
                  foregroundColor: RexUiTokens.textMuted,
                  disabledForegroundColor: RexUiTokens.textSubtle.withValues(
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
}
