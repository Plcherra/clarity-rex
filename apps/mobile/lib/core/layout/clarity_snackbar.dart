import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';

/// Width-only. Compact (`width < 800`), including Flutter web, clears the
/// bottom dock like the phone. Desktop `/app/` stays a top-end toast.
bool claritySnackBarUsesWideChrome(BuildContext context) {
  return isClarityDesktopLayout(context);
}

EdgeInsets claritySnackBarMargin(BuildContext context) {
  if (!claritySnackBarUsesWideChrome(context)) {
    return const EdgeInsets.fromLTRB(16, 16, 16, 88);
  }
  final width = MediaQuery.sizeOf(context).width;
  return EdgeInsets.only(
    top: 20,
    right: 20,
    left: width > 480 ? width - 420 : 20,
  );
}

/// Floating snackbar that clears the bottom dock; top-end on wide layouts.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showClaritySnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  final wide = claritySnackBarUsesWideChrome(context);
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: claritySnackBarMargin(context),
      dismissDirection: wide ? DismissDirection.up : DismissDirection.down,
    ),
  );
}
