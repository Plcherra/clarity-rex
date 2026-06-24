import 'package:flutter/material.dart';

class ClarityShadows {
  const ClarityShadows._();

  static List<BoxShadow> get softGlow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 18,
      spreadRadius: -10,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get panel => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 14,
      spreadRadius: -12,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get dropdown => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 14,
      spreadRadius: -8,
      offset: const Offset(0, 8),
    ),
  ];
}
