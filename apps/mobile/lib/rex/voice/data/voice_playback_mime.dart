/// Normalizes voice playback MIME types for browser `<audio>` and data URIs.
String normalizeVoicePlaybackMimeType(String contentType) {
  final normalized = contentType.split(';').first.trim().toLowerCase();
  switch (normalized) {
    case 'audio/mpeg':
    case 'audio/mp3':
      return 'audio/mpeg';
    case 'audio/mp4':
    case 'audio/aac':
    case 'audio/m4a':
      return 'audio/mp4';
    case 'audio/wav':
    case 'audio/wave':
    case 'audio/x-wav':
      return 'audio/wav';
    case 'audio/pcm':
    case 'audio/l16':
    case 'audio/linear16':
      return 'audio/pcm';
    default:
      return normalized.isEmpty ? 'audio/mpeg' : normalized;
  }
}

/// Minimal valid MPEG frame header for browser playback smoke tests.
List<int> minimalMpegAudioFrameBytes() {
  return const [
    0xFF,
    0xFB,
    0x90,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ];
}

/// Builds a data URI compatible with audioplayers web [BytesSource].
String voicePlaybackDataUri(List<int> bytes, String contentType) {
  final mimeType = normalizeVoicePlaybackMimeType(contentType);
  return Uri.dataFromBytes(bytes, mimeType: mimeType).toString();
}
