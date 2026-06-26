import 'package:flutter/material.dart';

import '../theme/clarity_gradients.dart';
import '../theme/clarity_radius.dart';

class ClarityCard extends StatelessWidget {
  const ClarityCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.constraints,
    this.width,
    this.highlighted = false,
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
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(ClarityRadius.card);
    final fillColor =
        backgroundColor ?? theme.cardTheme.color ?? cs.surfaceContainerLow;
    final content = Padding(padding: padding, child: child);

    final Widget card;
    if (borderColor != null) {
      card = Material(
        color: fillColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      );
    } else if (highlighted) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: ClarityGradients.cardEdge,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Material(
            color: fillColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: _insetRadius(radius)),
            clipBehavior: Clip.antiAlias,
            child: onTap == null
                ? content
                : InkWell(onTap: onTap, child: content),
          ),
        ),
      );
    } else {
      card = Material(
        color: fillColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      );
    }

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

  BorderRadiusGeometry _insetRadius(BorderRadiusGeometry radius) {
    if (radius is BorderRadius) {
      return BorderRadius.only(
        topLeft: Radius.circular(
          (radius.topLeft.x - 1).clamp(0.0, double.infinity),
        ),
        topRight: Radius.circular(
          (radius.topRight.x - 1).clamp(0.0, double.infinity),
        ),
        bottomLeft: Radius.circular(
          (radius.bottomLeft.x - 1).clamp(0.0, double.infinity),
        ),
        bottomRight: Radius.circular(
          (radius.bottomRight.x - 1).clamp(0.0, double.infinity),
        ),
      );
    }
    return radius;
  }
}
