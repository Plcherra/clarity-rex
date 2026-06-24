import 'package:flutter/material.dart';

import '../../theme/clarity_colors.dart';
import '../../widgets/clarity_card.dart';
import 'rex_ui_tokens.dart';

class RexTheme extends StatelessWidget {
  const RexTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class RexScaffold extends StatelessWidget {
  const RexScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool? resizeToAvoidBottomInset;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return RexTheme(
      child: Scaffold(
        appBar: appBar,
        backgroundColor: context.clarityColors.background,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        bottomNavigationBar: bottomNavigationBar,
        body: body,
      ),
    );
  }
}

class RexSurface extends StatelessWidget {
  const RexSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = RexUiTokens.radiusMedium,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return ClarityCard(
      margin: margin,
      padding: padding ?? EdgeInsets.zero,
      backgroundColor: color ?? colors.surface,
      borderColor: borderColor,
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}
