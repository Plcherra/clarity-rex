import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'package:clarity/rex/voice/data/voice_microphone_context.dart';

enum MicrophonePermissionDecision {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  insecureContext,
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
    if (kIsWeb && !isVoiceMicrophoneContextSecure()) {
      return MicrophonePermissionDecision.insecureContext;
    }

    if (kIsWeb) {
      if (await isWebMicrophonePermissionPermanentlyDenied()) {
        return MicrophonePermissionDecision.permanentlyDenied;
      }
      // Defer the real getUserMedia call to voice capture so we only open the
      // mic once. A throwaway probe can waste the tap gesture and bounce
      // Bluetooth headsets between A2DP and HFP before capture starts.
      return MicrophonePermissionDecision.granted;
    }

    try {
      final granted = await _recorder.hasPermission(request: true);
      if (granted) {
        return MicrophonePermissionDecision.granted;
      }

      return MicrophonePermissionDecision.denied;
    } on MissingPluginException {
      return MicrophonePermissionDecision.granted;
    } on PlatformException {
      return MicrophonePermissionDecision.denied;
    }
  }

  @override
  Future<void> openSettings() async {
    if (kIsWeb) {
      return;
    }

    try {
      await _settingsChannel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // Tests and unsupported platforms can run without native settings.
    } on Object {
      // Opening settings is helpful, but should never block voice recovery.
    }
  }
}
