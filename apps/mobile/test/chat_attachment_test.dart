import 'dart:typed_data';

import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat attachment validation', () {
    test('accepts common image attachments without UTF-8 validation', () {
      final error = validateChatAttachmentBytes(
        fileName: 'receipt.png',
        fileSize: 4,
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      );

      expect(error, isNull);
    });

    test('rejects oversized image attachments', () {
      final error = validateChatAttachment(
        fileName: 'receipt.jpg',
        fileSize: maxChatImageAttachmentBytes + 1,
      );

      expect(error, 'Image is too large. Maximum size is 5MB.');
    });

    test('accepts pdf attachments without UTF-8 validation', () {
      final error = validateChatAttachmentBytes(
        fileName: 'statement.pdf',
        fileSize: 4,
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );

      expect(error, isNull);
    });

    test('rejects oversized pdf attachments', () {
      final error = validateChatAttachment(
        fileName: 'statement.pdf',
        fileSize: maxChatPdfAttachmentBytes + 1,
      );

      expect(error, 'PDF is too large. Maximum size is 10MB.');
    });

    test('keeps text attachments strict UTF-8', () {
      final error = validateChatAttachmentBytes(
        fileName: 'notes.txt',
        fileSize: 2,
        bytes: Uint8List.fromList([0xFF, 0xFE]),
      );

      expect(error, 'Attachment must be valid UTF-8 text.');
    });
  });
}
