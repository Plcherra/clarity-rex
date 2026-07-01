import 'package:cross_file/cross_file.dart';

class RecordedVoiceAudio {
  const RecordedVoiceAudio({required this.file, required this.inputMimeType});

  final XFile file;
  final String inputMimeType;
}
