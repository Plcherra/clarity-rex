import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';

/// Floating snackbar that clears the bottom dock; top-end on wide web.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showClaritySnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  final wide = kIsWeb || isClarityDesktopLayout(context);
  final width = MediaQuery.sizeOf(context).width;
  final margin = wide
      ? EdgeInsets.only(
          top: 20,
          right: 20,
          left: width > 480 ? width - 420 : 20,
        )
      : const EdgeInsets.fromLTRB(16, 16, 16, 88);

  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: margin,
      dismissDirection: wide ? DismissDirection.up : DismissDirection.down,
    ),
  );
}
