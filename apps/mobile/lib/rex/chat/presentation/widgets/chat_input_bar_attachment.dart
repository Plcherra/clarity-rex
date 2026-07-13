import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_attachment_image.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

/// Attachment preview chip/thumbnail above the chat composer field.
class ChatInputAttachmentPreview extends StatelessWidget {
  const ChatInputAttachmentPreview({
    super.key,
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
    final isImage =
        !hasError && _isImageAttachment(title, attachment, previewBytes);
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
                        borderRadius: BorderRadius.circular(
                          RexUiTokens.radiusPill,
                        ),
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
