import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool isVoiceMicrophoneContextSecure() {
  return web.window.isSecureContext;
}

Future<bool> isWebMicrophonePermissionPermanentlyDenied() async {
  try {
    final status = await web.window.navigator.permissions
        .query({'name': 'microphone'}.jsify() as JSObject)
        .toDart;
    return status.state == 'denied';
  } on Object {
    return false;
  }
}

/// Requests microphone access via [getUserMedia].
///
/// Must invoke [getUserMedia] synchronously when this function is called so
/// the browser still has the user's click gesture (awaiting [permissions.query]
/// first — as the record package does — drops activation and suppresses the
/// prompt).
Future<bool> requestWebMicrophoneAccess() {
  return web.window.navigator.mediaDevices
      .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
      .toDart
      .then((stream) {
        for (final track in stream.getAudioTracks().toDart) {
          track.stop();
        }
        return true;
      })
      .catchError((_) => false);
}
