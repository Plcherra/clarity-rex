import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:clarity/rex/voice/data/voice_playback_mime.dart';

typedef AudioPlaybackCompleteCallback = void Function();
typedef AudioPlaybackErrorCallback = void Function(String message);

abstract class AudioPlaybackService {
  Future<void> playBase64Audio(
    String audioBase64, {
    required String contentType,
    required AudioPlaybackCompleteCallback onComplete,
    required AudioPlaybackErrorCallback onError,
  });

  Future<void> stop();

  Future<void> pause();
}

class PackageAudioPlaybackService implements AudioPlaybackService {
  PackageAudioPlaybackService({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer();

  final AudioPlayer _audioPlayer;

  @override
  Future<void> playBase64Audio(
    String audioBase64, {
    required String contentType,
    required AudioPlaybackCompleteCallback onComplete,
    required AudioPlaybackErrorCallback onError,
  }) async {
    final Uint8List audioBytes;
    try {
      audioBytes = base64Decode(audioBase64);
    } on FormatException {
      onError('Assistant returned invalid voice audio.');
      return;
    }
    if (audioBytes.isEmpty) {
      onError('Assistant returned empty voice audio.');
      return;
    }

    final mimeType = normalizeVoicePlaybackMimeType(contentType);

    try {
      await _audioPlayer.stop();
      if (!kIsWeb) {
        await _configureNativeAudioContext();
      }
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      final playbackComplete = _audioPlayer.onPlayerComplete.first;
      await _audioPlayer.play(BytesSource(audioBytes, mimeType: mimeType));
      if (kIsWeb) {
        await playbackComplete.timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            throw TimeoutException('Voice playback timed out.');
          },
        );
      } else {
        await playbackComplete;
      }
      onComplete();
    } on Object {
      onError('Voice playback failed.');
    }
  }

  Future<void> _configureNativeAudioContext() async {
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.voiceCommunication,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.allowAirPlay,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }
}
