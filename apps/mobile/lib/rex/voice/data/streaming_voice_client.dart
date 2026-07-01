/// Identifies the streaming voice client in Rex API session.start payloads.
String streamingVoiceClientTag({required bool isWeb}) {
  return isWeb ? 'flutter_streaming_web' : 'flutter_streaming';
}
