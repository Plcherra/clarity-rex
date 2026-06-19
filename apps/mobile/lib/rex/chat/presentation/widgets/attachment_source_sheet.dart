import 'package:flutter/material.dart';

import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

enum ChatAttachmentSource { gallery, camera, files }

class AttachmentSourceSheet extends StatelessWidget {
  const AttachmentSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: RexUiTokens.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Attach',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: RexUiTokens.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _AttachmentSourceTile(
              icon: Icons.photo_library_rounded,
              title: 'Gallery',
              subtitle: 'Choose an image from photos.',
              source: ChatAttachmentSource.gallery,
            ),
            _AttachmentSourceTile(
              icon: Icons.photo_camera_rounded,
              title: 'Camera',
              subtitle: 'Take a new photo.',
              source: ChatAttachmentSource.camera,
            ),
            _AttachmentSourceTile(
              icon: Icons.folder_rounded,
              title: 'Files',
              subtitle: 'Choose PDF, text, CSV, markdown, or image files.',
              source: ChatAttachmentSource.files,
            ),
          ],
        ),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: RexUiTokens.accent),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: RexUiTokens.text,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: RexUiTokens.textSubtle),
      ),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}
