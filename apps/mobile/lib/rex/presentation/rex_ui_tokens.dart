import 'package:flutter/material.dart';

class RexUiTokens {
  const RexUiTokens._();

  static const background = Color(0xFF080908);
  static const surface = Color(0xFF111311);
  static const surfaceSoft = Color(0xFF171A18);
  static const surfaceRaised = Color(0xFF20231F);
  static const border = Color(0xFF30352F);
  static const text = Color(0xFFF2F1EA);
  static const textMuted = Color(0xFFB7B3A7);
  static const textSubtle = Color(0xFF858073);
  static const accent = Color(0xFFD7BF57);
  static const accentStrong = Color(0xFFEBD56F);
  static const userBubble = Color(0xFF5F5609);
  static const danger = Color(0xFFFF706A);

  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;

  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusLarge = 14.0;
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
