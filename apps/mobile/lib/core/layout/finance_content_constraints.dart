import 'package:flutter/material.dart';

/// Breakpoint below which the shell uses a full-width bottom [NavigationBar].
const double homeShellCompactBreakpoint = 800;

/// Max width for shell tab content on ultra-wide viewports (all five tabs).
const double homeShellMaxContentWidth = 1440;

bool isHomeShellCompactWidth(BuildContext context) {
  return MediaQuery.sizeOf(context).width < homeShellCompactBreakpoint;
}

/// Centers shell tab content on ultra-wide viewports with a readable max width.
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

/// Alias for shared shell content width (finance + assistant + profile).
typedef ShellContentConstraints = FinanceContentConstraints;
