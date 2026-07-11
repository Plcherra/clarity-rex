import 'package:flutter/material.dart';

/// Page title + trailing actions constrained to the content column (not viewport edges).
class ShellPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const ShellPageHeader({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.leading,
    this.bottom,
  });

  final Widget title;
  final List<Widget> actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      actionsPadding: const EdgeInsets.only(right: 12),
    );
  }
}
