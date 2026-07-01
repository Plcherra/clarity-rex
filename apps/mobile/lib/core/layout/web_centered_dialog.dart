import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps Material dialogs so wide web viewports get a centered sheet, not full screen.
Widget wrapWebCenteredDialog(
  BuildContext context,
  Widget? child, {
  double maxWidth = 440,
  double maxHeight = 560,
}) {
  if (child == null) {
    return const SizedBox.shrink();
  }

  if (!kIsWeb) {
    return child;
  }

  return Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: child,
    ),
  );
}
