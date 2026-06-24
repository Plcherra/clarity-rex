import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/clarity_colors.dart';
import '../theme/clarity_gradients.dart';
import '../theme/clarity_radius.dart';

class ClarityDiamondLoader extends StatefulWidget {
  const ClarityDiamondLoader({super.key, this.size = 92, this.label});

  final double size;
  final String? label;

  @override
  State<ClarityDiamondLoader> createState() => _ClarityDiamondLoaderState();
}

class _ClarityDiamondLoaderState extends State<ClarityDiamondLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawLabel = widget.label?.trim();
    final label = rawLabel == null || rawLabel.isEmpty ? null : rawLabel;

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glowOpacity = 0.18 + (_pulse.value * 0.16);
          final scale = 0.96 + (_pulse.value * 0.04);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ClarityColors.deepBlue.withValues(
                                alpha: glowOpacity,
                              ),
                              blurRadius: widget.size * 0.38,
                              spreadRadius: widget.size * 0.04,
                            ),
                            BoxShadow(
                              color: ClarityColors.tealGlow.withValues(
                                alpha: glowOpacity * 0.8,
                              ),
                              blurRadius: widget.size * 0.42,
                              spreadRadius: widget.size * 0.02,
                            ),
                          ],
                        ),
                        child: SizedBox.square(dimension: widget.size * 0.62),
                      ),
                      Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: widget.size * 0.58,
                          height: widget.size * 0.58,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            gradient: ClarityGradients.primary,
                            borderRadius: BorderRadius.circular(
                              ClarityRadius.large,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: ClarityColors.surface.withValues(
                                alpha: 0.86,
                              ),
                              borderRadius: BorderRadius.circular(
                                ClarityRadius.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: 18),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ClarityColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
