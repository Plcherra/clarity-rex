import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A short burst over the whole screen when something is finished.
///
/// Reaching a goal is the one moment in the app worth marking, and a snackbar
/// does not mark it. Painted rather than pulled from a package: it is a few
/// dozen particles on one controller, and a dependency for that is a poor
/// trade.
///
/// Silently does nothing when the system asks for reduced motion.
Future<void> showClarityCelebrationBurst(BuildContext context) async {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  unawaited(HapticFeedback.mediumImpact());

  final entry = OverlayEntry(
    builder: (_) => const IgnorePointer(child: _CelebrationBurst()),
  );
  overlay.insert(entry);
  await Future<void>.delayed(_burstDuration);
  entry.remove();
}

const _burstDuration = Duration(milliseconds: 1500);
const _particleCount = 46;

class _CelebrationBurst extends StatefulWidget {
  const _CelebrationBurst();

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _burstDuration,
  )..forward();

  late final List<_Particle> _particles = _spawn();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _spawn() {
    // Seeded off nothing in particular — every burst should look a little
    // different, the way real confetti does.
    final random = math.Random();
    final palette = _paletteFor(Theme.of(context));
    return List.generate(_particleCount, (index) {
      final angle = (index / _particleCount) * math.pi * 2;
      return _Particle(
        angle: angle + random.nextDouble() * 0.5 - 0.25,
        speed: 0.35 + random.nextDouble() * 0.65,
        spin: random.nextDouble() * 6 - 3,
        size: 4 + random.nextDouble() * 5,
        color: palette[random.nextInt(palette.length)],
        delay: random.nextDouble() * 0.15,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            particles: _particles,
            progress: _controller.value,
          ),
        ),
      ),
    );
  }
}

List<Color> _paletteFor(ThemeData theme) {
  final scheme = theme.colorScheme;
  return [
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.primaryContainer,
  ];
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final double delay;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final reach = size.shortestSide * 0.9;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final t = ((progress - particle.delay) / (1 - particle.delay)).clamp(
        0.0,
        1.0,
      );
      if (t <= 0) continue;

      // Thrown outward, then pulled down: the arc is what makes it read as
      // confetti rather than a starburst.
      final distance =
          reach * particle.speed * Curves.easeOutCubic.transform(t);
      final drop = reach * 0.55 * t * t;
      final center =
          origin +
          Offset(
            math.cos(particle.angle) * distance,
            math.sin(particle.angle) * distance + drop,
          );

      paint.color = particle.color.withValues(
        alpha: (1 - Curves.easeInCubic.transform(t)).clamp(0.0, 1.0),
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(particle.spin * t * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 1.6,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
