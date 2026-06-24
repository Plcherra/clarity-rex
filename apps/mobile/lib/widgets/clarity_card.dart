import 'package:flutter/material.dart';

import '../theme/clarity_radius.dart';

class ClarityCard extends StatelessWidget {
  const ClarityCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.constraints,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final BoxConstraints? constraints;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(ClarityRadius.card);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(
        color: borderColor ?? cs.outline.withValues(alpha: 0.72),
      ),
    );
    final content = Padding(padding: padding, child: child);
    final card = Material(
      color: backgroundColor ?? theme.cardTheme.color ?? cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );

    Widget result = card;
    if (constraints != null || width != null) {
      result = ConstrainedBox(
        constraints: constraints ?? const BoxConstraints(),
        child: SizedBox(width: width, child: result),
      );
    }
    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }
    return result;
  }
}
