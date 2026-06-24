import 'package:flutter/material.dart';

import 'clarity_colors.dart';

class ClarityShadows {
  const ClarityShadows._();

  static List<BoxShadow> get softGlow => [
    BoxShadow(
      color: ClarityColors.deepBlue.withValues(alpha: 0.16),
      blurRadius: 24,
      spreadRadius: -10,
      offset: const Offset(-8, -6),
    ),
    BoxShadow(
      color: ClarityColors.tealGlow.withValues(alpha: 0.14),
      blurRadius: 28,
      spreadRadius: -12,
      offset: const Offset(10, 10),
    ),
  ];

  static List<BoxShadow> get panel => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.22),
      blurRadius: 18,
      spreadRadius: -10,
      offset: const Offset(0, 10),
    ),
  ];
}
