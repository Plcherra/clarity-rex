import 'package:flutter/material.dart';

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

  /// Pending confirm cards (chat + voice strip).
  static const confirmCardPadding = ClaritySpacing.md;
  static const confirmCardGap = ClaritySpacing.sm;
  static const confirmCardRadius = ClarityRadius.medium;
  static const confirmButtonHeight = 40.0;

  /// Chat composer chrome.
  static const composerPaddingH = ClaritySpacing.sm;
  static const composerPaddingTop = ClaritySpacing.xs;
  static const composerPaddingBottom = ClaritySpacing.sm;
  static const composerFieldPaddingV = ClaritySpacing.sm;

  static const radiusSmall = ClarityRadius.small;
  static const radiusMedium = ClarityRadius.medium;
  static const radiusLarge = ClarityRadius.large;
  static const radiusPill = ClarityRadius.pill;

  static ThemeData theme(BuildContext context) => Theme.of(context);
}
