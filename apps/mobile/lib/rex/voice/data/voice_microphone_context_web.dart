import 'dart:html' as html;

bool isVoiceMicrophoneContextSecure() {
  return html.window.isSecureContext ?? false;
}

Future<bool> isWebMicrophonePermissionPermanentlyDenied() async {
  try {
    final permissions = html.window.navigator.permissions;
    if (permissions == null) {
      return false;
    }

    final status = await permissions.query({'name': 'microphone'});
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
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    return Future.value(false);
  }

  return mediaDevices
      .getUserMedia({'audio': true})
      .then((stream) {
        for (final track in stream.getAudioTracks()) {
          track.stop();
        }
        return true;
      })
      .catchError((_) => false);
}
