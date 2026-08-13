import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';

/// Width-only. Compact (`width < 800`), including Flutter web, uses thin
/// auto-hiding thumbs like the phone. Desktop `/app/` keeps a visible thumb.
bool clarityScrollUsesDesktopChrome(BuildContext context) {
  return isClarityDesktopLayout(context);
}

ScrollbarThemeData clarityScrollbarTheme(
  ColorScheme scheme, {
  required bool desktop,
}) {
  return ScrollbarThemeData(
    thumbVisibility: WidgetStatePropertyAll(desktop),
    thickness: WidgetStatePropertyAll(desktop ? 8.0 : 4.0),
    radius: const Radius.circular(8),
    thumbColor: WidgetStatePropertyAll(
      scheme.onSurface.withValues(alpha: desktop ? 0.28 : 0.18),
    ),
  );
}

ScrollbarThemeData clarityScrollbarThemeOf(BuildContext context) {
  return clarityScrollbarTheme(
    Theme.of(context).colorScheme,
    desktop: clarityScrollUsesDesktopChrome(context),
  );
}

/// Clamping on desktop for mouse-wheel feel; bouncing on compact width.
ScrollPhysics clarityScrollPhysics(BuildContext context) {
  if (clarityScrollUsesDesktopChrome(context)) {
    return const ClampingScrollPhysics();
  }
  return const BouncingScrollPhysics();
}
