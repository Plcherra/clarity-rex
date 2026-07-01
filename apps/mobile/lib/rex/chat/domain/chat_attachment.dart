import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;

import 'package:clarity/l10n/app_localizations.dart';

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

String resolvedChatAttachmentFileName(XFile attachment) {
  final name = chatAttachmentName(attachment);
  if (p.extension(name).isNotEmpty) {
    return name;
  }

  final mimeType = attachment.mimeType?.trim().toLowerCase();
  final extension = switch (mimeType) {
    'application/pdf' => '.pdf',
    'text/csv' => '.csv',
    'text/plain' => '.txt',
    'text/markdown' => '.md',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '',
  };
  if (extension.isEmpty) {
    return name;
  }
  return '$name$extension';
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
  required AppLocalizations l10n,
  required String fileName,
  required int fileSize,
}) {
  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  if (allowedTextChatAttachmentExtensions.contains(extension)) {
    if (fileSize > maxChatAttachmentBytes) {
      return l10n.chatAttachmentTooLarge;
    }
    return null;
  }

  if (allowedImageChatAttachmentExtensions.contains(extension)) {
    if (fileSize > maxChatImageAttachmentBytes) {
      return l10n.chatAttachmentImageTooLarge;
    }
    return null;
  }

  if (allowedPdfChatAttachmentExtensions.contains(extension)) {
    if (fileSize > maxChatPdfAttachmentBytes) {
      return l10n.chatAttachmentPdfTooLarge;
    }
    return null;
  }

  return l10n.chatAttachmentInvalidType;
}

String? validateChatAttachmentBytes({
  required AppLocalizations l10n,
  required String fileName,
  required int fileSize,
  required Uint8List bytes,
}) {
  final metadataError = validateChatAttachment(
    l10n: l10n,
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
    return l10n.chatAttachmentUtf8Required;
  }

  return null;
}

Future<String?> validateChatAttachmentFile(
  XFile attachment, {
  required AppLocalizations l10n,
}) async {
  final fileName = chatAttachmentName(attachment);
  late final int fileSize;

  try {
    fileSize = await attachment.length();
  } on Object {
    return l10n.chatAttachmentReadFailed;
  }

  final metadataError = validateChatAttachment(
    l10n: l10n,
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
    return l10n.chatAttachmentUtf8Required;
  } on Object {
    return l10n.chatAttachmentReadFailed;
  }

  return null;
}
