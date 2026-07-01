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
