import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;

const int maxChatAttachmentBytes = 2 * 1024 * 1024;
const int maxChatImageAttachmentBytes = 5 * 1024 * 1024;
const int maxChatPdfAttachmentBytes = 10 * 1024 * 1024;
const Set<String> allowedTextChatAttachmentExtensions = {'txt', 'md', 'csv'};
const Set<String> allowedPdfChatAttachmentExtensions = {'pdf'};
const Set<String> allowedImageChatAttachmentExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
};
const Set<String> allowedChatAttachmentExtensions = {
  ...allowedTextChatAttachmentExtensions,
  ...allowedPdfChatAttachmentExtensions,
  ...allowedImageChatAttachmentExtensions,
};

String chatAttachmentName(XFile attachment) {
  if (attachment.name.trim().isNotEmpty) {
    return attachment.name.trim();
  }

  return p.basename(attachment.path);
}

String? chatAttachmentContentType(String fileName) {
  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  return switch (extension) {
    'txt' => 'text/plain',
    'md' => 'text/markdown',
    'csv' => 'text/csv',
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => null,
  };
}

String formatAttachmentSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

bool isChatImageAttachmentName(String fileName) {
  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  return allowedImageChatAttachmentExtensions.contains(extension);
}

String? validateChatAttachment({
  required String fileName,
  required int fileSize,
}) {
  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  if (allowedTextChatAttachmentExtensions.contains(extension)) {
    if (fileSize > maxChatAttachmentBytes) {
      return 'Attachment is too large. Maximum size is 2MB.';
    }
    return null;
  }

  if (allowedImageChatAttachmentExtensions.contains(extension)) {
    if (fileSize > maxChatImageAttachmentBytes) {
      return 'Image is too large. Maximum size is 5MB.';
    }
    return null;
  }

  if (allowedPdfChatAttachmentExtensions.contains(extension)) {
    if (fileSize > maxChatPdfAttachmentBytes) {
      return 'PDF is too large. Maximum size is 10MB.';
    }
    return null;
  }

  return 'Attach a .txt, .md, .csv, .pdf, .jpg, .png, or .webp file.';
}

String? validateChatAttachmentBytes({
  required String fileName,
  required int fileSize,
  required Uint8List bytes,
}) {
  final metadataError = validateChatAttachment(
    fileName: fileName,
    fileSize: fileSize,
  );
  if (metadataError != null) {
    return metadataError;
  }

  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  if (allowedImageChatAttachmentExtensions.contains(extension) ||
      allowedPdfChatAttachmentExtensions.contains(extension)) {
    return null;
  }

  try {
    utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return 'Attachment must be valid UTF-8 text.';
  }

  return null;
}

Future<String?> validateChatAttachmentFile(XFile attachment) async {
  final fileName = chatAttachmentName(attachment);
  late final int fileSize;

  try {
    fileSize = await attachment.length();
  } on Object {
    return 'Could not read selected file.';
  }

  final metadataError = validateChatAttachment(
    fileName: fileName,
    fileSize: fileSize,
  );
  if (metadataError != null) {
    return metadataError;
  }

  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  if (allowedImageChatAttachmentExtensions.contains(extension) ||
      allowedPdfChatAttachmentExtensions.contains(extension)) {
    return null;
  }

  try {
    final bytes = await attachment.readAsBytes();
    utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return 'Attachment must be valid UTF-8 text.';
  } on Object {
    return 'Could not read selected file.';
  }

  return null;
}
