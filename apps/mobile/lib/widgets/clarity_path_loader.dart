import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/l10n/app_l10n.dart';
import '../theme/clarity_colors.dart';

class ClarityPathLoader extends StatefulWidget {
  const ClarityPathLoader({
    super.key,
    this.size = 48,
    this.strokeWidth,
    this.label,
    this.duration = const Duration(milliseconds: 1350),
    this.compact = false,
    this.showLabel = true,
  });

  final double size;
  final double? strokeWidth;
  final String? label;
  final Duration duration;
  final bool compact;
  final bool showLabel;

  @override
  State<ClarityPathLoader> createState() => _ClarityPathLoaderState();
}

class _ClarityPathLoaderState extends State<ClarityPathLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant ClarityPathLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawLabel = widget.label?.trim();
    final label = rawLabel == null || rawLabel.isEmpty ? null : rawLabel;
    final showTextLabel = widget.showLabel && label != null && !widget.compact;
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Semantics(
      label: label ?? context.l10n.commonLoading,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ClarityPathLoaderPainter(
                    progress: _controller.value,
                    accent: colors.accent,
                    accentStrong: colors.accentStrong,
                    strokeWidth:
                        widget.strokeWidth ??
                        (widget.compact
                            ? widget.size * 0.1
                            : widget.size * 0.055),
                    compact: widget.compact,
                  ),
                );
              },
            ),
          ),
          if (showTextLabel) ...[
            SizedBox(height: (widget.size * 0.2).clamp(10.0, 18.0)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.05,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ClarityInlineLoader extends StatelessWidget {
  const ClarityInlineLoader({super.key, this.size = 18, this.strokeWidth});

  final double size;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClarityPathLoader(
        size: size,
        strokeWidth: strokeWidth ?? (size * 0.11),
        compact: true,
        showLabel: false,
      ),
    );
  }
}

class _ClarityPathLoaderPainter extends CustomPainter {
  const _ClarityPathLoaderPainter({
    required this.progress,
    required this.accent,
    required this.accentStrong,
    required this.strokeWidth,
    required this.compact,
  });

  final double progress;
  final Color accent;
  final Color accentStrong;
  final double strokeWidth;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final inset = strokeWidth * (compact ? 2.1 : 2.9);
    final side = math.max(0.0, shortest - inset * 2);
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side * 0.72,
      height: side * 0.72,
    );
    final radius = Radius.circular(rect.width * 0.18);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
    final metric = path.computeMetrics().first;
    final length = metric.length;
    final head = progress * length;
    final tailLength = length * (compact ? 0.34 : 0.3);
    final segmentCount = compact ? 14 : 22;

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(math.pi / 4)
      ..translate(-size.width / 2, -size.height / 2);

    for (var i = 0; i < segmentCount; i += 1) {
      final startT = i / segmentCount;
      final endT = (i + 1) / segmentCount;
      final start = head - tailLength + tailLength * startT;
      final end = head - tailLength + tailLength * endT;
      final intensity = Curves.easeOutCubic.transform(endT);
      final color = Color.lerp(
        accent,
        accentStrong,
        intensity,
      )!.withValues(alpha: (0.08 + intensity * 0.92).clamp(0.0, 1.0));

      if (!compact) {
        _drawPathSegment(
          canvas,
          metric,
          length,
          start,
          end,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = strokeWidth * 2.8
            ..color = color.withValues(alpha: 0.18 + intensity * 0.2)
            ..maskFilter = ui.MaskFilter.blur(
              ui.BlurStyle.normal,
              strokeWidth * 1.8,
            ),
        );
      }

      _drawPathSegment(
        canvas,
        metric,
        length,
        start,
        end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = strokeWidth
          ..color = color,
      );
    }

    final tangent = metric.getTangentForOffset(head % length);
    if (tangent != null) {
      final headPaint = Paint()
        ..color = accentStrong.withValues(alpha: compact ? 0.75 : 0.9)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          strokeWidth * (compact ? 0.7 : 1.1),
        );
      canvas.drawCircle(
        tangent.position,
        strokeWidth * (compact ? 0.75 : 0.95),
        headPaint,
      );
    }

    canvas.restore();
  }

  void _drawPathSegment(
    Canvas canvas,
    ui.PathMetric metric,
    double length,
    double rawStart,
    double rawEnd,
    Paint paint,
  ) {
    var start = rawStart % length;
    var end = rawEnd % length;
    if (start < 0) start += length;
    if (end < 0) end += length;

    if (rawEnd - rawStart >= length) {
      canvas.drawPath(metric.extractPath(0, length), paint);
      return;
    }

    if (start <= end) {
      canvas.drawPath(metric.extractPath(start, end), paint);
      return;
    }

    canvas
      ..drawPath(metric.extractPath(start, length), paint)
      ..drawPath(metric.extractPath(0, end), paint);
  }

  @override
  bool shouldRepaint(covariant _ClarityPathLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.accentStrong != accentStrong ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.compact != compact;
  }
}
