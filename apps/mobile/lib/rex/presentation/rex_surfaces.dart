import 'package:flutter/material.dart';

import '../../widgets/clarity_card.dart';
import 'rex_ui_tokens.dart';

class RexTheme extends StatelessWidget {
  const RexTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: RexUiTokens.darkTheme(context), child: child);
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
        backgroundColor: RexUiTokens.background,
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
    this.color = RexUiTokens.surface,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClarityCard(
      margin: margin,
      padding: padding ?? EdgeInsets.zero,
      backgroundColor: color,
      borderColor: borderColor ?? RexUiTokens.border.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}
