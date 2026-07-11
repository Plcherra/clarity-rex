import 'package:flutter/material.dart';

/// Breakpoint below which the shell uses a full-width bottom [NavigationBar].
const double homeShellCompactBreakpoint = 800;

/// Outer shell content cap on ultra-wide viewports.
const double homeShellMaxContentWidth = 1440;

bool isHomeShellCompactWidth(BuildContext context) {
  return MediaQuery.sizeOf(context).width < homeShellCompactBreakpoint;
}

/// Centers [child] with a surface-specific max width.
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
