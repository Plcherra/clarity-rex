import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/finance_content_constraints.dart';
import '../../../theme/clarity_colors.dart';
import '../../../theme/clarity_radius.dart';

export '../../../core/layout/finance_content_constraints.dart';

/// Max width for the centered bottom dock on wide viewports.
const double homeShellDockMaxWidth = 600;

/// Adaptive shell navigation: full-width bottom bar below
/// [homeShellCompactBreakpoint], centered bottom dock at wider widths.
/// Never uses [NavigationRail].
class HomeShellAdaptiveScaffold extends StatelessWidget {
  const HomeShellAdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final compact = isHomeShellCompactWidth(context);

    if (compact) {
      // Phone-width, including Flutter web: selected-label only.
      return Scaffold(
        body: body,
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: Theme.of(context).navigationBarTheme.copyWith(
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        ),
      );
    }

    return _HomeShellWideScaffold(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      body: body,
    );
  }
}

/// True when a text field owns keyboard focus so digit 1–5 can type, not switch tabs.
bool homeShellTextInputHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText ||
      context.widget is TextField ||
      context.widget is TextFormField) {
    return true;
  }
  if (context.findAncestorWidgetOfExactType<EditableText>() != null ||
      context.findAncestorWidgetOfExactType<TextField>() != null ||
      context.findAncestorWidgetOfExactType<TextFormField>() != null) {
    return true;
  }
  var found = false;
  void visit(Element element) {
    if (found) return;
    if (element.widget is EditableText) {
      found = true;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return found;
}

int? _homeShellDigitDestinationIndex(LogicalKeyboardKey key, int destinationCount) {
  const digitKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];
  final index = digitKeys.indexOf(key);
  if (index < 0 || index >= destinationCount) return null;
  return index;
}

class _HomeShellWideScaffold extends StatelessWidget {
  const _HomeShellWideScaffold({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (homeShellTextInputHasFocus()) return KeyEventResult.ignored;
        final index = _homeShellDigitDestinationIndex(
          event.logicalKey,
          destinations.length,
        );
        if (index == null) return KeyEventResult.ignored;
        onDestinationSelected(index);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: _HomeShellCenteredDock(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      ),
    );
  }
}

class _HomeShellCenteredDock extends StatelessWidget {
  const _HomeShellCenteredDock({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;

    // Must shrink-wrap vertically: Align without heightFactor expands to the
    // Scaffold's full max height for bottomNavigationBar and starves the body.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: homeShellDockMaxWidth),
              child: Material(
                color: colors.surfaceElevated,
                elevation: 2,
                shadowColor: colors.textPrimary.withValues(alpha: 0.12),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClarityRadius.pill),
                  side: BorderSide(color: colors.border.withValues(alpha: 0.55)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    navigationBarTheme: Theme.of(context).navigationBarTheme
                        .copyWith(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          height: 56,
                        ),
                  ),
                  child: NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: [
                      for (var i = 0; i < destinations.length; i++)
                        NavigationDestination(
                          icon: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Tooltip(
                              message: '${destinations[i].label} (${i + 1})',
                              child: destinations[i].icon,
                            ),
                          ),
                          selectedIcon: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Tooltip(
                              message: '${destinations[i].label} (${i + 1})',
                              child:
                                  destinations[i].selectedIcon ??
                                  destinations[i].icon,
                            ),
                          ),
                          label: destinations[i].label,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
