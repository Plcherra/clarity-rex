import 'package:flutter/services.dart';
import 'package:record/record.dart';

enum MicrophonePermissionDecision {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

abstract class MicrophonePermissionService {
  Future<MicrophonePermissionDecision> requestMicrophonePermission({
    bool includeSpeechRecognition = true,
  });

  Future<void> openSettings();
}

class RecordMicrophonePermissionService implements MicrophonePermissionService {
  RecordMicrophonePermissionService({
    AudioRecorder? recorder,
    MethodChannel? settingsChannel,
  }) : _recorder = recorder ?? AudioRecorder(),
       _settingsChannel =
           settingsChannel ?? const MethodChannel('clarity/voice_audio');

  final AudioRecorder _recorder;
  final MethodChannel _settingsChannel;

  @override
  Future<MicrophonePermissionDecision> requestMicrophonePermission({
    bool includeSpeechRecognition = true,
  }) async {
    try {
      final granted = await _recorder.hasPermission();
      return granted
          ? MicrophonePermissionDecision.granted
          : MicrophonePermissionDecision.denied;
    } on MissingPluginException {
      return MicrophonePermissionDecision.granted;
    } on PlatformException {
      return MicrophonePermissionDecision.denied;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _settingsChannel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // Tests and unsupported platforms can run without native settings.
    } on Object {
      // Opening settings is helpful, but should never block voice recovery.
    }
  }
}
