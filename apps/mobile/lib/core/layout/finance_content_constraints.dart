import 'package:flutter/material.dart';

import 'clarity_breakpoints.dart';

/// Breakpoint below which the shell uses a full-width bottom [NavigationBar].
const double homeShellCompactBreakpoint = clarityLayoutMediumBreakpoint;

/// Outer shell content cap on ultra-wide viewports.
const double homeShellMaxContentWidth = clarityFinanceContentMaxWidth;

bool isHomeShellCompactWidth(BuildContext context) {
  return MediaQuery.sizeOf(context).width < homeShellCompactBreakpoint;
}

/// Centers [child] with a surface-specific max width, filling most of the viewport.
class ShellContentConstraints extends StatelessWidget {
  const ShellContentConstraints({
    super.key,
    required this.child,
    this.maxWidth = homeShellMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = clarityClampedContentWidth(context, maxWidth);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

/// Back-compat alias used by finance screens that wrap themselves.
class FinanceContentConstraints extends StatelessWidget {
  const FinanceContentConstraints({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShellContentConstraints(
      maxWidth: homeShellMaxContentWidth,
      child: child,
    );
  }
}
