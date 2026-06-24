import 'package:flutter/material.dart';

import '../../theme/clarity_colors.dart';
import '../../theme/clarity_radius.dart';
import '../../theme/clarity_spacing.dart';
import '../../theme/clarity_theme.dart';

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
  static const accentStrong = ClarityColors.electricBlue;
  static const userBubble = ClarityColors.deepBlue;
  static const danger = ClarityColors.danger;

  static const space2 = ClaritySpacing.xxs;
  static const space4 = ClaritySpacing.xs;
  static const space8 = ClaritySpacing.sm;
  static const space12 = ClaritySpacing.md;
  static const space16 = ClaritySpacing.lg;
  static const space20 = ClaritySpacing.xl;
  static const space24 = ClaritySpacing.xxl;

  static const radiusSmall = ClarityRadius.small;
  static const radiusMedium = ClarityRadius.medium;
  static const radiusLarge = ClarityRadius.large;
  static const radiusPill = ClarityRadius.pill;

  static ThemeData darkTheme(BuildContext context) {
    return ClarityTheme.dark();
  }
}
