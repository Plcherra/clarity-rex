import 'package:flutter/material.dart';

import '../theme/clarity_colors.dart';
import '../theme/clarity_gradients.dart';
import '../theme/clarity_radius.dart';
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

    final Widget button = switch (variant) {
      ClarityButtonVariant.filled => _GradientFilledButton(
        onPressed: effectiveOnPressed,
        icon: hasLeading ? leading : null,
        label: label,
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

class _GradientFilledButton extends StatelessWidget {
  const _GradientFilledButton({
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(ClarityRadius.medium);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: enabled
            ? ClarityGradients.primary
            : LinearGradient(
                colors: [
                  ClarityColors.surfaceSoft,
                  ClarityColors.surfaceSoft,
                ],
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: ClarityColors.tealGlow.withValues(alpha: 0.16),
          highlightColor: ClarityColors.electricBlue.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      color: enabled
                          ? ClarityColors.textPrimary
                          : ClarityColors.textMuted,
                      size: 20,
                    ),
                    child: icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: enabled
                        ? ClarityColors.textPrimary
                        : ClarityColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClarityButtonLoader extends StatelessWidget {
  const _ClarityButtonLoader();

  @override
  Widget build(BuildContext context) {
    return const ClarityInlineLoader(size: 18, strokeWidth: 2);
  }
}
