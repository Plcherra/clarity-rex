bool isVoiceMicrophoneContextSecure() => true;

Future<bool> isWebMicrophonePermissionPermanentlyDenied() async => false;

Future<bool> requestWebMicrophoneAccess() async => true;
