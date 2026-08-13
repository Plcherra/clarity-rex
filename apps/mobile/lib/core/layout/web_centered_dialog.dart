import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';

/// Constrains Material dialogs on desktop so they stay centered.
/// Compact width (`width < 800`), including Flutter web, returns [child] as-is.
Widget wrapWebCenteredDialog(
  BuildContext context,
  Widget? child, {
  double maxWidth = 440,
  double maxHeight = 560,
}) {
  if (child == null) {
    return const SizedBox.shrink();
  }

  if (!isClarityDesktopLayout(context)) {
    return child;
  }

  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: child,
    ),
  );
}
