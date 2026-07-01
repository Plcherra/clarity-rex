import 'dart:async';

import 'package:audio_session/audio_session.dart';

import 'audio_session_service.dart';
import 'background_voice_service.dart';
import 'native_voice_session_service.dart';

/// No-op voice services used on web (and other unsupported targets) so Riverpod
/// providers never touch native MethodChannels or EventChannels at boot.
final class NoOpBackgroundVoiceService implements BackgroundVoiceService {
  const NoOpBackgroundVoiceService();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

final class NoOpNativeVoiceSessionService implements NativeVoiceSessionService {
  const NoOpNativeVoiceSessionService();

  @override
  Stream<NativeVoiceEvent> get events => const Stream<NativeVoiceEvent>.empty();

  @override
  Future<void> startSession(NativeVoiceSessionConfig config) async {}

  @override
  Future<void> stopSession() async {}

  @override
  Future<void> interrupt() async {}

  @override
  Future<void> setMuted(bool isMuted) async {}

  @override
  Future<void> setForegroundState(bool isForeground) async {}
}

final class NoOpVoiceAudioSessionService implements VoiceAudioSessionService {
  const NoOpVoiceAudioSessionService();

  @override
  Future<void> configureForVoiceTurn() async {}

  @override
  Future<void> preferLoudSpeaker() async {}

  @override
  Future<void> setActive(bool active) async {}

  @override
  StreamSubscription<void> listenForNoisyAudio(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    return const Stream<void>.empty().listen((_) {});
  }

  @override
  StreamSubscription<AudioInterruptionEvent> listenForInterruptions(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    return const Stream<AudioInterruptionEvent>.empty().listen((_) {});
  }
}
