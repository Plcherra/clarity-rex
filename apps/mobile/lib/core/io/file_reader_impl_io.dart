import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<String> readPickedFileContents(PlatformFile file) async {
  try {
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  } on Object {
    throw const FormatException('Could not read file.');
  }
}
