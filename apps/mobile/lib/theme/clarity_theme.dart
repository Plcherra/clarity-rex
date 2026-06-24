import 'package:flutter/material.dart';

import 'clarity_colors.dart';
import 'clarity_radius.dart';

class ClarityTheme {
  const ClarityTheme._();

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ClarityColors.electricBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: ClarityColors.electricBlue,
          onPrimary: ClarityColors.textPrimary,
          secondary: ClarityColors.teal,
          onSecondary: ClarityColors.appBackground,
          error: ClarityColors.danger,
          onError: ClarityColors.textPrimary,
          surface: ClarityColors.appBackground,
          onSurface: ClarityColors.textPrimary,
          surfaceContainerLowest: ClarityColors.appBackground,
          surfaceContainerLow: ClarityColors.surface,
          surfaceContainer: ClarityColors.surface,
          surfaceContainerHigh: ClarityColors.surfaceElevated,
          surfaceContainerHighest: ClarityColors.surfaceSoft,
          onSurfaceVariant: ClarityColors.textSecondary,
          outline: ClarityColors.mutedBorder,
          outlineVariant: ClarityColors.subtleBlueBorder,
          shadow: Colors.black,
          scrim: Colors.black,
        );
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: scheme);
    final outlineSoft = ClarityColors.mutedBorder.withValues(alpha: 0.72);

    return baseTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ClarityColors.appBackground,
      canvasColor: ClarityColors.appBackground,
      colorScheme: scheme,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: ClarityColors.textPrimary,
        displayColor: ClarityColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: ClarityColors.textSecondary),
      primaryIconTheme: const IconThemeData(color: ClarityColors.textPrimary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ClarityColors.tealGlow,
        circularTrackColor: ClarityColors.surfaceElevated,
        linearTrackColor: ClarityColors.surfaceElevated,
        linearMinHeight: 5,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ClarityColors.teal,
        selectionColor: Color(0x5535D6C8),
        selectionHandleColor: ClarityColors.teal,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: ClarityColors.appBackground,
        foregroundColor: ClarityColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: ClarityColors.textPrimary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              foregroundColor: ClarityColors.textSecondary,
              disabledForegroundColor: ClarityColors.textMuted,
              minimumSize: const Size.square(44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return ClarityColors.tealGlow.withValues(alpha: 0.12);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return ClarityColors.electricBlue.withValues(alpha: 0.10);
                }
                return null;
              }),
            ),
      ),
      cardTheme: CardThemeData(
        color: ClarityColors.cardFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.card),
          side: BorderSide(color: outlineSoft),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ClarityColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.dialog),
          side: const BorderSide(color: ClarityColors.mutedBorder),
        ),
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
          color: ClarityColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: ClarityColors.textSecondary,
          height: 1.35,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ClarityColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ClarityColors.surfaceElevated,
        modalBarrierColor: Color(0xB3050D1A),
        dragHandleColor: ClarityColors.mutedBorder,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: ClarityColors.surfaceElevated,
        actionTextColor: ClarityColors.teal,
        contentTextStyle: const TextStyle(color: ClarityColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          side: BorderSide(color: outlineSoft),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ClarityColors.textSecondary,
        textColor: ClarityColors.textPrimary,
        subtitleTextStyle: TextStyle(
          color: ClarityColors.textSecondary,
          fontSize: 14,
          height: 1.25,
        ),
        titleTextStyle: TextStyle(
          color: ClarityColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: ClarityColors.appBackground,
        indicatorColor: ClarityColors.deepBlue.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.pill),
          side: BorderSide(
            color: ClarityColors.activeBorder.withValues(alpha: 0.72),
          ),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? ClarityColors.tealGlow : ClarityColors.textMuted,
            size: selected ? 25 : 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? ClarityColors.textPrimary
                : ClarityColors.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.05,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return ClarityColors.tealGlow.withValues(alpha: 0.10);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return ClarityColors.electricBlue.withValues(alpha: 0.08);
          }
          return null;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ClarityColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.large),
          side: BorderSide(color: outlineSoft),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              foregroundColor: ClarityColors.textPrimary,
              backgroundColor: ClarityColors.deepBlue,
              disabledForegroundColor: ClarityColors.textMuted,
              disabledBackgroundColor: ClarityColors.surfaceSoft,
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
                  return ClarityColors.tealGlow.withValues(alpha: 0.16);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return ClarityColors.electricBlue.withValues(alpha: 0.12);
                }
                return null;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClarityColors.textPrimary,
          disabledForegroundColor: ClarityColors.textMuted,
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
          foregroundColor: ClarityColors.teal,
          disabledForegroundColor: ClarityColors.textMuted,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ClarityColors.surface,
        iconColor: ClarityColors.textSecondary,
        prefixIconColor: ClarityColors.textSecondary,
        suffixIconColor: ClarityColors.textSecondary,
        hintStyle: const TextStyle(color: ClarityColors.textMuted),
        labelStyle: const TextStyle(color: ClarityColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: ClarityColors.teal),
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
          borderSide: const BorderSide(
            color: ClarityColors.activeBorder,
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: const BorderSide(color: ClarityColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.medium),
          borderSide: const BorderSide(color: ClarityColors.danger, width: 1.2),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: ClarityColors.surfaceElevated,
        selectedColor: ClarityColors.deepBlue.withValues(alpha: 0.22),
        disabledColor: ClarityColors.surfaceSoft,
        labelStyle: const TextStyle(color: ClarityColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: ClarityColors.textPrimary),
        side: BorderSide(color: outlineSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClarityRadius.pill),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineSoft,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
