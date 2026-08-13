import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';
import '../../theme/clarity_sheet_insets.dart';

/// Width-only. Compact (`width < 800`), including Flutter web, uses a sheet.
/// Desktop `/app/` stays a centered dialog.
bool clarityAdaptiveOverlayUsesDialog(BuildContext context) {
  return isClarityDesktopLayout(context);
}

/// Shows a centered dialog on desktop, bottom sheet on compact width.
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
  final useDialog = clarityAdaptiveOverlayUsesDialog(context);

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
