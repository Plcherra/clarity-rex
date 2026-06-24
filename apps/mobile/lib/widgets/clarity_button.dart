import 'package:flutter/material.dart';

import 'clarity_path_loader.dart';

enum ClarityButtonVariant { filled, outlined, text }

class ClarityButton extends StatelessWidget {
  const ClarityButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ClarityButtonVariant.filled,
    this.isLoading = false,
    this.expanded = false,
    this.style,
  });

  const ClarityButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.style,
  }) : variant = ClarityButtonVariant.filled;

  const ClarityButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.style,
  }) : variant = ClarityButtonVariant.outlined;

  const ClarityButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.style,
  }) : variant = ClarityButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final ClarityButtonVariant variant;
  final bool isLoading;
  final bool expanded;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final leading = isLoading ? const _ClarityButtonLoader() : icon;
    final hasLeading = leading != null;

    final button = switch (variant) {
      ClarityButtonVariant.filled =>
        hasLeading
            ? FilledButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: leading,
                label: Text(label),
              )
            : FilledButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: Text(label),
              ),
      ClarityButtonVariant.outlined =>
        hasLeading
            ? OutlinedButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: leading,
                label: Text(label),
              )
            : OutlinedButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: Text(label),
              ),
      ClarityButtonVariant.text =>
        hasLeading
            ? TextButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: leading,
                label: Text(label),
              )
            : TextButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: Text(label),
              ),
    };

    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

class _ClarityButtonLoader extends StatelessWidget {
  const _ClarityButtonLoader();

  @override
  Widget build(BuildContext context) {
    return const ClarityInlineLoader(size: 18, strokeWidth: 2);
  }
}
