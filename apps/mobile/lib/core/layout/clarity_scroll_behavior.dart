import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web/desktop scrollbars show a visible thumb; mobile stays auto.
ScrollbarThemeData clarityScrollbarTheme(ColorScheme scheme) {
  return ScrollbarThemeData(
    thumbVisibility: WidgetStatePropertyAll(kIsWeb),
    thickness: WidgetStatePropertyAll(kIsWeb ? 8.0 : 4.0),
    radius: const Radius.circular(8),
    thumbColor: WidgetStatePropertyAll(
      scheme.onSurface.withValues(alpha: kIsWeb ? 0.28 : 0.18),
    ),
  );
}

/// Prefer clamping physics on web/desktop for mouse wheel feel.
ScrollPhysics clarityScrollPhysics(BuildContext context) {
  if (kIsWeb || MediaQuery.sizeOf(context).width >= 800) {
    return const ClampingScrollPhysics();
  }
  return const BouncingScrollPhysics();
}
