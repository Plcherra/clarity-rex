import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'chat_local_file_image_io.dart'
    if (dart.library.html) 'chat_local_file_image_stub.dart';

/// Renders a chat attachment image from in-memory bytes, with an optional
/// local file path fallback on IO platforms.
class ChatAttachmentImage extends StatelessWidget {
  const ChatAttachmentImage({
    super.key,
    this.previewBytes,
    this.localPath,
    this.fit = BoxFit.cover,
    this.width,
    this.maxHeight,
    this.filterQuality = FilterQuality.medium,
  });

  final Uint8List? previewBytes;
  final String? localPath;
  final BoxFit fit;
  final double? width;
  final double? maxHeight;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final bytes = previewBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: maxHeight,
        filterQuality: filterQuality,
      );
    }

    final path = localPath?.trim() ?? '';
    if (path.isNotEmpty) {
      return buildChatLocalFileImage(
        path: path,
        fit: fit,
        width: width,
        maxHeight: maxHeight,
        filterQuality: filterQuality,
      );
    }

    return SizedBox(
      height: maxHeight ?? 96,
      width: width,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
  }
}
