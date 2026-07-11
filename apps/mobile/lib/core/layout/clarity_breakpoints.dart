import 'package:flutter/material.dart';

import 'finance_content_constraints.dart';

/// Shared layout breakpoints for Clarity web/desktop composition.
enum ClarityLayoutSize { compact, medium, wide }

const double clarityLayoutMediumBreakpoint = homeShellCompactBreakpoint;
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

/// Content max widths by surface (inside the shell).
const double clarityFinanceContentMaxWidth = 1200;
const double clarityAssistantContentMaxWidth = 900;
const double clarityProfileContentMaxWidth = 720;
const double clarityChatColumnMaxWidth = 760;
