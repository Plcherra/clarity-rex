import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_connectivity_stub.dart'
    if (dart.library.html) 'device_connectivity_web.dart'
    if (dart.library.io) 'device_connectivity_io.dart'
    as impl;

typedef DeviceOnlineCheck = Future<bool> Function();

/// Test hook so unit tests skip real DNS / navigator checks.
@visibleForTesting
DeviceOnlineCheck? debugDeviceOnlineCheckOverride;

/// Light launch preflight: true when the device appears to have network.
///
/// Used before voice start and confirm so we can show [chatErrorNetwork]
/// without claiming a save. Not a connectivity_plus dependency.
Future<bool> isDeviceLikelyOnline() {
  final override = debugDeviceOnlineCheckOverride;
  if (override != null) {
    return override();
  }
  return impl.isDeviceLikelyOnline();
}

final deviceOnlineCheckProvider = Provider<DeviceOnlineCheck>(
  (ref) => isDeviceLikelyOnline,
);
