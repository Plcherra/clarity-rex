import 'dart:io';

import 'package:clarity/core/rex/rex_config.dart';

/// Deliberate UX preflight reachability (not a race-condition patch).
///
/// Caps wait at 2s so a clearly offline device fails fast before voice start
/// or confirm. Uses the configured API host when remote; otherwise a public
/// DNS name so localhost-dev configs still detect real offline.
Future<bool> isDeviceLikelyOnline() async {
  final host = _reachabilityHost();
  try {
    final results = await InternetAddress.lookup(
      host,
    ).timeout(const Duration(seconds: 2));
    return results.isNotEmpty && results.first.rawAddress.isNotEmpty;
  } on Object {
    return false;
  }
}

String _reachabilityHost() {
  try {
    final host = Uri.parse(RexConfig.backendBaseUrl).host.trim().toLowerCase();
    if (host.isNotEmpty &&
        host != 'localhost' &&
        host != '127.0.0.1' &&
        host != '::1') {
      return host;
    }
  } on Object {
    // Fall through to public DNS probe.
  }
  return 'example.com';
}
