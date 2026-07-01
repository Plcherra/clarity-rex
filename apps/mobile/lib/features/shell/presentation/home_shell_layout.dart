import 'package:flutter/material.dart';

import '../../../core/layout/finance_content_constraints.dart';

export '../../../core/layout/finance_content_constraints.dart';

/// Adaptive shell navigation: bottom bar below [homeShellCompactBreakpoint],
/// [NavigationRail] at wider widths.
class HomeShellAdaptiveScaffold extends StatelessWidget {
  const HomeShellAdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.railDestinations,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final List<NavigationRailDestination> railDestinations;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final compact = isHomeShellCompactWidth(context);

    if (compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: railDestinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
