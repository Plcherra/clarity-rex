import 'dart:typed_data';

import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupEnglishLocalizationsForTests();

  group('chat attachment validation', () {
    test('accepts common image attachments without UTF-8 validation', () {
      final error = validateChatAttachmentBytes(
        l10n: l10n,
        fileName: 'receipt.png',
        fileSize: 4,
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      );

      expect(error, isNull);
    });

    test('rejects oversized image attachments', () {
      final error = validateChatAttachment(
        l10n: l10n,
        fileName: 'receipt.jpg',
        fileSize: maxChatImageAttachmentBytes + 1,
      );

      expect(error, l10n.chatAttachmentImageTooLarge);
    });

    test('accepts pdf attachments without UTF-8 validation', () {
      final error = validateChatAttachmentBytes(
        l10n: l10n,
        fileName: 'statement.pdf',
        fileSize: 4,
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );

      expect(error, isNull);
    });

    test('maps supported attachment names to upload content types', () {
      expect(chatAttachmentContentType('statement.pdf'), 'application/pdf');
      expect(chatAttachmentContentType('notes.md'), 'text/markdown');
      expect(chatAttachmentContentType('transactions.csv'), 'text/csv');
      expect(chatAttachmentContentType('receipt.jpg'), 'image/jpeg');
      expect(chatAttachmentContentType('receipt.png'), 'image/png');
      expect(chatAttachmentContentType('archive.zip'), isNull);
    });

    test('rejects oversized pdf attachments', () {
      final error = validateChatAttachment(
        l10n: l10n,
        fileName: 'statement.pdf',
        fileSize: maxChatPdfAttachmentBytes + 1,
      );

      expect(error, l10n.chatAttachmentPdfTooLarge);
    });

    test('keeps text attachments strict UTF-8', () {
      final error = validateChatAttachmentBytes(
        l10n: l10n,
        fileName: 'notes.txt',
        fileSize: 2,
        bytes: Uint8List.fromList([0xFF, 0xFE]),
      );

      expect(error, l10n.chatAttachmentUtf8Required);
    });
  });
}
