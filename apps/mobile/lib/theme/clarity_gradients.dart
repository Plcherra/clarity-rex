import 'package:flutter/material.dart';

import 'clarity_colors.dart';

class ClarityGradients {
  const ClarityGradients._();

  static const primary = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [ClarityColors.teal, ClarityColors.tealGlow],
  );

  static const appBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      ClarityColors.appBackground,
      ClarityColors.surface,
      ClarityColors.appBackground,
    ],
  );

  static const cardEdge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ClarityColors.subtleBorder, ClarityColors.mutedBorder],
  );
}
