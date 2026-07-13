import 'package:flutter/material.dart';

import '../../core/layout/clarity_breakpoints.dart';
import '../../theme/clarity_colors.dart';
import '../../theme/clarity_radius.dart';
import '../../theme/clarity_spacing.dart';

class RexUiTokens {
  const RexUiTokens._();

  static const background = ClarityColors.appBackground;
  static const surface = ClarityColors.surface;
  static const surfaceSoft = ClarityColors.surfaceElevated;
  static const surfaceRaised = ClarityColors.surfaceSoft;
  static const border = ClarityColors.mutedBorder;
  static const text = ClarityColors.textPrimary;
  static const textMuted = ClarityColors.textSecondary;
  static const textSubtle = ClarityColors.textMuted;
  static const accent = ClarityColors.teal;
  static const accentStrong = ClarityColors.tealGlow;
  /// Legacy solid fill — chat bubbles use theme `accentSoft` instead.
  static const userBubble = ClarityColors.teal;
  static const danger = ClarityColors.danger;

  static const space2 = ClaritySpacing.xxs;
  static const space4 = ClaritySpacing.xs;
  static const space8 = ClaritySpacing.sm;
  static const space12 = ClaritySpacing.md;
  static const space16 = ClaritySpacing.lg;
  static const space20 = ClaritySpacing.xl;
  static const space24 = ClaritySpacing.xxl;

  /// Chat transcript density (shared across chat + voice interim rows).
  static const bubblePaddingH = ClaritySpacing.md;
  static const bubblePaddingV = ClaritySpacing.sm;
  static const messageGap = ClaritySpacing.sm;
  static const bubbleSideInset = 36.0;

  /// Knows list row density (shared tile shell).
  static const memoryTilePaddingH = ClaritySpacing.sm;
  static const memoryTilePaddingV = ClaritySpacing.sm;
  static const memoryTileRadius = ClarityRadius.small;

  /// Pending confirm cards (chat + voice strip) — desktop / wide defaults.
  static const confirmCardPadding = ClaritySpacing.md;
  static const confirmCardGap = ClaritySpacing.sm;
  static const confirmCardRadius = ClarityRadius.medium;
  static const confirmButtonHeight = 40.0;

  /// Chat composer chrome — desktop / wide defaults.
  static const composerPaddingH = ClaritySpacing.sm;
  static const composerPaddingTop = ClaritySpacing.xs;
  /// Explicit bottom inset — web SafeArea is often 0, so this must clear the edge.
  static const composerPaddingBottom = ClaritySpacing.xxl;
  static const composerFieldPaddingV = ClaritySpacing.sm;
  static const composerIconSize = 40.0;

  static const radiusSmall = ClarityRadius.small;
  static const radiusMedium = ClarityRadius.medium;
  static const radiusLarge = ClarityRadius.large;
  static const radiusPill = ClarityRadius.pill;

  /// Phone / narrow width — denser confirm + composer without affecting wide `/app/`.
  static bool isCompactChrome(BuildContext context) {
    return !isClarityDesktopLayout(context);
  }

  static double confirmCardPaddingOf(BuildContext context) {
    return isCompactChrome(context) ? ClaritySpacing.sm : confirmCardPadding;
  }

  static double confirmButtonHeightOf(BuildContext context) {
    return isCompactChrome(context) ? 36.0 : confirmButtonHeight;
  }

  static double confirmBorderWidthOf(BuildContext context) {
    return isCompactChrome(context) ? 1.0 : 1.25;
  }

  static double confirmBorderAlphaOf(BuildContext context) {
    return isCompactChrome(context) ? 0.28 : 0.42;
  }

  static TextStyle? confirmTitleFieldStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
  }

  static TextStyle? confirmBodyFieldStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35);
  }

  static EdgeInsets confirmFieldContentPadding(BuildContext context) {
    if (isCompactChrome(context)) {
      return const EdgeInsets.symmetric(
        horizontal: ClaritySpacing.sm,
        vertical: ClaritySpacing.xs,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: ClaritySpacing.sm,
      vertical: ClaritySpacing.sm,
    );
  }

  static double composerPaddingHOf(BuildContext context) {
    return isCompactChrome(context) ? ClaritySpacing.xs : composerPaddingH;
  }

  static double composerPaddingTopOf(BuildContext context) {
    return isCompactChrome(context) ? ClaritySpacing.xxs : composerPaddingTop;
  }

  static double composerPaddingBottomOf(BuildContext context) {
    return isCompactChrome(context) ? ClaritySpacing.lg : composerPaddingBottom;
  }

  static double composerFieldPaddingVOf(BuildContext context) {
    return isCompactChrome(context) ? ClaritySpacing.xs : composerFieldPaddingV;
  }

  static double composerIconSizeOf(BuildContext context) {
    return isCompactChrome(context) ? 36.0 : composerIconSize;
  }

  static ThemeData theme(BuildContext context) => Theme.of(context);
}
