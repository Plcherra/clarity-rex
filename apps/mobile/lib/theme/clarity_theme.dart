import 'package:flutter/material.dart';

import 'clarity_colors.dart';
import 'clarity_radius.dart';

class ClarityTheme {
  const ClarityTheme._();

  static ThemeData dark() => _build(ClarityColors.dark, Brightness.dark);

  static ThemeData light() => _build(ClarityColors.light, Brightness.light);

  static ThemeData _build(ClarityColorTokens colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: isDark ? Colors.black : Colors.white,
          secondary: colors.accentStrong,
          onSecondary: isDark ? Colors.black : Colors.white,
          error: colors.danger,
          onError: Colors.white,
          surface: colors.background,
          onSurface: colors.textPrimary,
          surfaceContainerLowest: colors.background,
          surfaceContainerLow: colors.surface,
          surfaceContainer: colors.surface,
          surfaceContainerHigh: colors.surfaceElevated,
          surfaceContainerHighest: colors.surfaceSoft,
          onSurfaceVariant: colors.textSecondary,
          outline: colors.border,
          outlineVariant: colors.divider,
          shadow: Colors.black,
          scrim: Colors.black,
        );
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: scheme);
    final outlineSoft = colors.border.withValues(alpha: isDark ? 0.70 : 0.95);
    final overlay = colors.accent.withValues(alpha: isDark ? 0.10 : 0.08);

    return baseTheme.copyWith(
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      colorScheme: scheme,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      iconTheme: IconThemeData(color: colors.textSecondary),
      primaryIconTheme: IconThemeData(color: colors.textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        circularTrackColor: colors.surfaceElevated,
        linearTrackColor: colors.surfaceElevated,
        linearMinHeight: 5,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.22),
        selectionHandleColor: colors.accent,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: colors.textPrimary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              foregroundColor: colors.textSecondary,
              disabledForegroundColor: colors.textMuted,
              minimumSize: const Size.square(44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return overlay;
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return overlay;
                }
                return null;
              }),
            ),
      ),
      cardTheme: CardThemeData(
        color: colors.cardFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.card),
          side: BorderSide(color: colors.divider),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.dialog),
          side: BorderSide(color: outlineSoft),
        ),
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
          height: 1.35,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surfaceElevated,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.70 : 0.35),
        dragHandleColor: colors.divider,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: colors.surfaceElevated,
        actionTextColor: colors.accent,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          side: BorderSide(color: outlineSoft),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        subtitleTextStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          height: 1.25,
        ),
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: colors.background,
        indicatorColor: colors.accent.withValues(alpha: isDark ? 0.16 : 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.pill),
          side: BorderSide(color: colors.borderActive.withValues(alpha: 0.50)),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.accent : colors.textMuted,
            size: selected ? 25 : 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? colors.textPrimary : colors.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.05,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return overlay;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return overlay;
          }
          return null;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 2 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.large),
          side: BorderSide(color: outlineSoft),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              foregroundColor: isDark ? Colors.black : Colors.white,
              backgroundColor: colors.accent,
              disabledForegroundColor: colors.textMuted,
              disabledBackgroundColor: colors.surfaceSoft,
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.15,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ClarityRadius.medium),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05);
                }
                return null;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textMuted,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.15,
            fontSize: 15,
          ),
          side: BorderSide(color: outlineSoft),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClarityRadius.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          disabledForegroundColor: colors.textMuted,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        iconColor: colors.textSecondary,
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        hintStyle: TextStyle(color: colors.textMuted),
        labelStyle: TextStyle(color: colors.textSecondary),
        floatingLabelStyle: TextStyle(color: colors.accent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: BorderSide(color: outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: BorderSide(color: outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: BorderSide(color: colors.borderActive, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: BorderSide(color: colors.danger, width: 1.2),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: colors.surfaceElevated,
        selectedColor: colors.accent.withValues(alpha: isDark ? 0.18 : 0.12),
        disabledColor: colors.surfaceSoft,
        labelStyle: TextStyle(color: colors.textPrimary),
        secondaryLabelStyle: TextStyle(color: colors.textPrimary),
        side: BorderSide(color: outlineSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.pill),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
