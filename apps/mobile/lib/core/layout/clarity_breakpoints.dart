import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared layout breakpoints for Clarity web/desktop composition.
enum ClarityLayoutSize { compact, medium, wide }

/// Breakpoint below which the shell uses a full-width bottom [NavigationBar].
const double clarityLayoutMediumBreakpoint = 800;
const double clarityLayoutWideBreakpoint = 1100;

ClarityLayoutSize clarityLayoutSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < clarityLayoutMediumBreakpoint) {
    return ClarityLayoutSize.compact;
  }
  if (width < clarityLayoutWideBreakpoint) {
    return ClarityLayoutSize.medium;
  }
  return ClarityLayoutSize.wide;
}

bool isClarityDesktopLayout(BuildContext context) {
  return clarityLayoutSizeOf(context) != ClarityLayoutSize.compact;
}

bool isClarityWideLayout(BuildContext context) {
  return clarityLayoutSizeOf(context) == ClarityLayoutSize.wide;
}

/// Preferred max widths. [ShellContentConstraints] also clamps to the viewport
/// minus gutters so wide screens fill most of the window.
const double clarityFinanceContentMaxWidth = 1920;
const double clarityAssistantContentMaxWidth = 1920;
const double clarityProfileContentMaxWidth = 1120;
const double clarityChatColumnMaxWidth = 960;
const double clarityDesktopContentGutter = 24;

/// Usable content width: fill the viewport with modest gutters, up to [preferredMax].
double clarityClampedContentWidth(
  BuildContext context,
  double preferredMax, {
  double gutter = clarityDesktopContentGutter,
}) {
  final viewport = MediaQuery.sizeOf(context).width;
  final available = math.max(320.0, viewport - gutter * 2);
  return math.min(preferredMax, available);
}
