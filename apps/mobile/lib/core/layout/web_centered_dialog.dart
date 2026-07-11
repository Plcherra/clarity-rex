import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Constrains Material dialogs on wide web/desktop so they stay centered.
Widget wrapWebCenteredDialog(
  BuildContext context,
  Widget? child, {
  double maxWidth = 440,
  double maxHeight = 560,
}) {
  if (child == null) {
    return const SizedBox.shrink();
  }

  final width = MediaQuery.sizeOf(context).width;
  if (!kIsWeb && width < 800) {
    return child;
  }

  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: child,
    ),
  );
}
