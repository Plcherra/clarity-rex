import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

class PermissionHandlerMicrophonePermissionService
    implements MicrophonePermissionService {
  @override
  Future<MicrophonePermissionDecision> requestMicrophonePermission({
    bool includeSpeechRecognition = true,
  }) async {
    final microphoneStatus = await _requestPermission(Permission.microphone);
    if (microphoneStatus.isPermanentlyDenied) {
      return MicrophonePermissionDecision.permanentlyDenied;
    }
    if (microphoneStatus.isRestricted) {
      return MicrophonePermissionDecision.restricted;
    }
    if (!microphoneStatus.isGranted) {
      return MicrophonePermissionDecision.denied;
    }

    if (includeSpeechRecognition) {
      final speechStatus = await _requestPermission(Permission.speech);
      if (speechStatus.isPermanentlyDenied) {
        return MicrophonePermissionDecision.permanentlyDenied;
      }
      if (speechStatus.isRestricted) {
        return MicrophonePermissionDecision.restricted;
      }
      if (!speechStatus.isGranted) {
        return MicrophonePermissionDecision.denied;
      }
    }

    return MicrophonePermissionDecision.granted;
  }

  @override
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } on MissingPluginException {
      // Desktop test/runtime targets may not provide permission_handler.
    }
  }

  Future<PermissionStatus> _requestPermission(Permission permission) async {
    try {
      final currentStatus = await permission.status;
      if (currentStatus.isGranted) {
        return currentStatus;
      }
      return permission.request();
    } on MissingPluginException {
      return PermissionStatus.granted;
    } on PlatformException catch (error) {
      if (error.code == 'ERROR_ALREADY_REQUESTING_PERMISSIONS') {
        return PermissionStatus.denied;
      }
      rethrow;
    }
  }
}
