import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';
import '../../theme/clarity_sheet_insets.dart';

/// Shows a centered dialog on web/desktop, bottom sheet on compact mobile.
Future<T?> showClarityAdaptiveOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  Color? backgroundColor,
  double dialogMaxWidth = 720,
  double dialogMaxHeight = 720,
  bool barrierDismissible = true,
}) {
  final useDialog = kIsWeb || isClarityDesktopLayout(context);

  if (useDialog) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor:
              backgroundColor ?? theme.colorScheme.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: dialogMaxHeight,
            ),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }

  return showClarityModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}
