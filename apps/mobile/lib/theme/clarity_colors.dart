import 'package:flutter/material.dart';

@immutable
class ClarityColorTokens extends ThemeExtension<ClarityColorTokens> {
  const ClarityColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSoft,
    required this.cardFill,
    required this.accent,
    required this.accentSoft,
    required this.accentStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderActive,
    required this.divider,
    required this.danger,
    required this.warning,
    required this.financePositive,
    required this.financeNegative,
    required this.financeSpending,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSoft;
  final Color cardFill;
  final Color accent;
  final Color accentSoft;
  final Color accentStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderActive;
  final Color divider;
  final Color danger;
  final Color warning;
  final Color financePositive;
  final Color financeNegative;
  final Color financeSpending;

  @override
  ClarityColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSoft,
    Color? cardFill,
    Color? accent,
    Color? accentSoft,
    Color? accentStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderActive,
    Color? divider,
    Color? danger,
    Color? warning,
    Color? financePositive,
    Color? financeNegative,
    Color? financeSpending,
  }) {
    return ClarityColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      cardFill: cardFill ?? this.cardFill,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentStrong: accentStrong ?? this.accentStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderActive: borderActive ?? this.borderActive,
      divider: divider ?? this.divider,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      financePositive: financePositive ?? this.financePositive,
      financeNegative: financeNegative ?? this.financeNegative,
      financeSpending: financeSpending ?? this.financeSpending,
    );
  }

  @override
  ClarityColorTokens lerp(ThemeExtension<ClarityColorTokens>? other, double t) {
    if (other is! ClarityColorTokens) return this;
    return ClarityColorTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      cardFill: Color.lerp(cardFill, other.cardFill, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderActive: Color.lerp(borderActive, other.borderActive, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      financePositive: Color.lerp(financePositive, other.financePositive, t)!,
      financeNegative: Color.lerp(financeNegative, other.financeNegative, t)!,
      financeSpending: Color.lerp(financeSpending, other.financeSpending, t)!,
    );
  }
}

class ClarityColors {
  const ClarityColors._();

  static const dark = ClarityColorTokens(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF151515),
    surfaceElevated: Color(0xFF1D1D1D),
    surfaceSoft: Color(0xFF242424),
    cardFill: Color(0xF2151515),
    accent: Color(0xFF00E5C0),
    accentSoft: Color(0x3322E8CE),
    accentStrong: Color(0xFF52F3DC),
    textPrimary: Color(0xFFF4F4F4),
    textSecondary: Color(0xFFA7A7A7),
    textMuted: Color(0xFF777777),
    border: Color(0x293A3A3A),
    borderActive: Color(0x6633E7CF),
    divider: Color(0x1F8A8A8A),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    financePositive: Color(0xFF34D399),
    financeNegative: Color(0xFFF87171),
    financeSpending: Color(0xFFE86A72),
  );

  static const light = ClarityColorTokens(
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F3F5),
    surfaceSoft: Color(0xFFE9ECEF),
    cardFill: Color(0xFFFFFFFF),
    accent: Color(0xFF00BFA5),
    accentSoft: Color(0x2400BFA5),
    accentStrong: Color(0xFF008C7A),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF555555),
    textMuted: Color(0xFF767676),
    border: Color(0xFFE5E7EB),
    borderActive: Color(0x6600BFA5),
    divider: Color(0xFFE8EAED),
    danger: Color(0xFFEF4444),
    warning: Color(0xFFD97706),
    financePositive: Color(0xFF10B981),
    financeNegative: Color(0xFFEF4444),
    financeSpending: Color(0xFFDC2626),
  );

  // Compatibility aliases. New code should prefer Theme.of(context) or
  // context.clarityColors so light and dark mode can adapt correctly.
  static const appBackground = Color(0xFF0A0A0A);
  static const surface = Color(0xFF151515);
  static const surfaceElevated = Color(0xFF1D1D1D);
  static const surfaceSoft = Color(0xFF242424);
  static const cardFill = Color(0xF2151515);

  static const teal = Color(0xFF00E5C0);
  static const tealGlow = Color(0xFF52F3DC);

  static const textPrimary = Color(0xFFF4F4F4);
  static const textSecondary = Color(0xFFA7A7A7);
  static const textMuted = Color(0xFF777777);

  static const mutedBorder = Color(0x293A3A3A);
  static const activeBorder = Color(0x6633E7CF);
  static const subtleBorder = Color(0x1F8A8A8A);

  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const positive = Color(0xFF00E5C0);

  // Financial semantic colors stay calmer than the brand teal/alert red.
  static const financePositive = Color(0xFF34D399);
  static const financeNegative = Color(0xFFF87171);
  static const financeSpending = Color(0xFFE86A72);
}

extension ClarityColorTokensX on BuildContext {
  ClarityColorTokens get clarityColors {
    final tokens = Theme.of(this).extension<ClarityColorTokens>();
    return tokens ?? ClarityColors.dark;
  }
}
