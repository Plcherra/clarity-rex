import 'package:flutter/material.dart';

/// The card the category drill-down sections sit in.
class CategoryDetailPanel extends StatelessWidget {
  const CategoryDetailPanel({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.78)),
      ),
      child: child,
    );
  }
}
