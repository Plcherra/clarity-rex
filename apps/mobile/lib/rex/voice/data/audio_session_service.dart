import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';

typedef VoiceAudioInterruptionCallback = void Function(String message);
typedef VoiceAudioInterruptionBeginCallback = void Function();
typedef VoiceAudioInterruptionEndCallback = void Function();

abstract class VoiceAudioSessionService {
  Future<void> configureForVoiceTurn();

  Future<void> preferLoudSpeaker();

  Future<void> setActive(bool active);

  StreamSubscription<void> listenForNoisyAudio(
    VoiceAudioInterruptionCallback onInterrupted,
  );

  /// AVAudioSession / Android focus interruptions (screenshot, calls, Siri).
  /// Begin must hold utterance.end; end recovers listen without sending.
  StreamSubscription<AudioInterruptionEvent> listenForInterruptions({
    required VoiceAudioInterruptionBeginCallback onBegin,
    VoiceAudioInterruptionEndCallback? onEnd,
  });
}

class PackageVoiceAudioSessionService implements VoiceAudioSessionService {
  PackageVoiceAudioSessionService({MethodChannel? voiceAudioChannel})
    : _voiceAudioChannel =
          voiceAudioChannel ?? const MethodChannel('clarity/voice_audio');

  final MethodChannel _voiceAudioChannel;
  AudioSession? _session;

  @override
  Future<void> configureForVoiceTurn() async {
    try {
      final session = await _audioSession();
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp |
              AVAudioSessionCategoryOptions.allowAirPlay |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          // voiceChat enables system AEC — required once mic stays open while
          // Rex speaks (barge-in / conversational duplex).
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      await session.setActive(true);
      await preferLoudSpeaker();
    } on MissingPluginException {
      // Tests and unsupported platforms can run without native audio sessions.
    } on Object {
      // Audio-session setup should improve reliability, not block voice mode.
    }
  }

  @override
  Future<void> preferLoudSpeaker() async {
    try {
      await _voiceAudioChannel.invokeMethod<void>('preferLoudSpeaker');
    } on MissingPluginException {
      // Android, tests, and old builds can rely on audio-session flags.
    } on Object {
      // Speaker preference should never block voice mode.
    }
  }

  @override
  Future<void> setActive(bool active) async {
    try {
      final session = await _audioSession();
      await session.setActive(active);
    } on MissingPluginException {
      // Tests and unsupported platforms can run without native audio sessions.
    } on Object {
      // Audio-session cleanup should never break controller disposal.
    }
  }

  @override
  StreamSubscription<void> listenForNoisyAudio(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    final session = _session;
    if (session == null) {
      return const Stream<void>.empty().listen((_) {});
    }
    try {
      return session.becomingNoisyEventStream.listen((_) {
        onInterrupted(
          'Audio route changed. Restart the voice turn if Rex stopped hearing you.',
        );
      });
    } on Object {
      return const Stream<void>.empty().listen((_) {});
    }
  }

  @override
  StreamSubscription<AudioInterruptionEvent> listenForInterruptions({
    required VoiceAudioInterruptionBeginCallback onBegin,
    VoiceAudioInterruptionEndCallback? onEnd,
  }) {
    final session = _session;
    if (session == null) {
      return const Stream<AudioInterruptionEvent>.empty().listen((_) {});
    }
    try {
      return session.interruptionEventStream.listen((event) {
        if (event.type == AudioInterruptionType.duck) {
          return;
        }
        if (event.begin) {
          onBegin();
        } else {
          onEnd?.call();
        }
      });
    } on Object {
      return const Stream<AudioInterruptionEvent>.empty().listen((_) {});
    }
  }

  Future<AudioSession> _audioSession() async {
    final existing = _session;
    if (existing != null) {
      return existing;
    }
    final session = await AudioSession.instance;
    _session = session;
    return session;
  }
}
