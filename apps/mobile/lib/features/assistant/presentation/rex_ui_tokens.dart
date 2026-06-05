import 'package:flutter/material.dart';

class RexUiTokens {
  const RexUiTokens._();

  static const background = Color(0xFF10100D);
  static const surface = Color(0xFF191811);
  static const surfaceSoft = Color(0xFF222016);
  static const surfaceRaised = Color(0xFF2B281C);
  static const border = Color(0xFF3A3728);
  static const text = Color(0xFFF4F0E6);
  static const textMuted = Color(0xFFBEB7A7);
  static const textSubtle = Color(0xFF8F8878);
  static const accent = Color(0xFFE5CD6A);
  static const accentStrong = Color(0xFFFFE377);
  static const userBubble = Color(0xFF746A05);
  static const danger = Color(0xFFFF706A);

  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;

  static const radiusSmall = 10.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 24.0;
  static const radiusPill = 999.0;

  static ThemeData darkTheme(BuildContext context) {
    final base = Theme.of(context);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: accent,
          onPrimary: background,
          secondary: accentStrong,
          surface: background,
          onSurface: text,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: surfaceSoft,
          surfaceContainerHighest: surfaceRaised,
          onSurfaceVariant: textMuted,
          outline: border,
          outlineVariant: border,
          error: danger,
          shadow: Colors.black,
        );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border.withValues(alpha: 0.7),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      iconTheme: base.iconTheme.copyWith(color: textMuted),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: surfaceRaised,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: text),
      ),
    );
  }
}
