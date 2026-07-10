import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/theme/clarity_colors.dart';

enum ChatAttachmentSource { gallery, camera, files }

class AttachmentSourceSheet extends StatelessWidget {
  const AttachmentSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.attachmentSheetTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _AttachmentSourceTile(
            icon: Icons.photo_library_rounded,
            title: l10n.attachmentSheetGalleryTitle,
            subtitle: l10n.attachmentSheetGallerySubtitle,
            source: ChatAttachmentSource.gallery,
          ),
          _AttachmentSourceTile(
            icon: Icons.photo_camera_rounded,
            title: l10n.attachmentSheetCameraTitle,
            subtitle: l10n.attachmentSheetCameraSubtitle,
            source: ChatAttachmentSource.camera,
          ),
          _AttachmentSourceTile(
            icon: Icons.folder_rounded,
            title: l10n.attachmentSheetFilesTitle,
            subtitle: l10n.attachmentSheetFilesSubtitle,
            source: ChatAttachmentSource.files,
          ),
        ],
      ),
    );
  }
}

class _AttachmentSourceTile extends StatelessWidget {
  const _AttachmentSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.source,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ChatAttachmentSource source;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.accent),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      ),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}
