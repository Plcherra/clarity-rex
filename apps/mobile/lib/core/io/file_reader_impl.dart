import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Web / non-IO: bytes only.
Future<String> readPickedFileContents(PlatformFile file) async {
  try {
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  } on Object {
    throw const FormatException('Could not read CSV data from this picker.');
  }
}
