import 'package:flutter/material.dart';

/// Shared bottom-sheet padding: keyboard inset only.
/// Prefer [showClarityModalBottomSheet] / `useSafeArea: true` for home-indicator.
EdgeInsets claritySheetPadding(
  BuildContext context, {
  double horizontal = 20,
  double top = 8,
  double bottom = 20,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom + MediaQuery.viewInsetsOf(context).bottom,
  );
}

/// Extra scroll clearance when the body sits above a shell bottom bar.
/// Uses [MediaQuery.padding] (already reduced by Scaffold + NavigationBar) so
/// we do not double-count the home indicator on iOS.
double clarityScrollBottomClearance(
  BuildContext context, {
  double minimum = 24,
}) {
  final paddingBottom = MediaQuery.paddingOf(context).bottom;
  if (paddingBottom > 0) {
    return paddingBottom + 8;
  }
  return minimum;
}

/// Standard modal sheet: drag-to-dismiss, grabber, safe area (iOS + Android).
Future<T?> showClarityModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    enableDrag: true,
    isDismissible: true,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}
