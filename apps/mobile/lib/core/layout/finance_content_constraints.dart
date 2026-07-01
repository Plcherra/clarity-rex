import 'package:flutter/material.dart';

/// Breakpoint below which the shell uses bottom [NavigationBar] (mobile layout).
const double homeShellCompactBreakpoint = 800;

/// Max width for finance tab content on ultra-wide viewports.
const double homeShellMaxContentWidth = 1320;

bool isHomeShellCompactWidth(BuildContext context) {
  return MediaQuery.sizeOf(context).width < homeShellCompactBreakpoint;
}

/// Centers finance screens on ultra-wide viewports with a readable max width.
class FinanceContentConstraints extends StatelessWidget {
  const FinanceContentConstraints({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: homeShellMaxContentWidth),
        child: child,
      ),
    );
  }
}
