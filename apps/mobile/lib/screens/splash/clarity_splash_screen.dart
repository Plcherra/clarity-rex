import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/clarity_colors.dart';
import '../../theme/clarity_gradients.dart';

class ClaritySplashScreen extends StatefulWidget {
  const ClaritySplashScreen({
    super.key,
    required this.child,
    required this.isReady,
    this.assetPath = 'assets/brand/clarity_splash_mark.png',
    this.minDuration = const Duration(milliseconds: 900),
    this.fadeDuration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final bool isReady;
  final String assetPath;
  final Duration minDuration;
  final Duration fadeDuration;

  @override
  State<ClaritySplashScreen> createState() => _ClaritySplashScreenState();
}

class _ClaritySplashScreenState extends State<ClaritySplashScreen> {
  Timer? _minDisplayTimer;
  var _minDisplayElapsed = false;
  var _overlayVisible = true;
  var _overlayMounted = true;

  @override
  void initState() {
    super.initState();
    _minDisplayTimer = Timer(widget.minDuration, () {
      if (!mounted) return;
      setState(() => _minDisplayElapsed = true);
      _maybeDismissOverlay();
    });
  }

  @override
  void didUpdateWidget(covariant ClaritySplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady != oldWidget.isReady) {
      _maybeDismissOverlay();
    }
  }

  void _maybeDismissOverlay() {
    if (!_overlayVisible || !widget.isReady || !_minDisplayElapsed) return;

    setState(() => _overlayVisible = false);
  }

  @override
  void dispose() {
    _minDisplayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_overlayMounted)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: AnimatedOpacity(
                opacity: _overlayVisible ? 1 : 0,
                duration: widget.fadeDuration,
                curve: Curves.easeOutCubic,
                onEnd: () {
                  if (_overlayVisible || !mounted) return;
                  setState(() => _overlayMounted = false);
                },
                child: _SplashVisual(assetPath: widget.assetPath),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashVisual extends StatelessWidget {
  const _SplashVisual({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeOf(context)?.size ?? const Size(390, 844);
    final logoSize = (size.shortestSide * 0.58).clamp(190.0, 280.0);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: ClarityColors.appBackground,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: ClarityGradients.appBackground,
          ),
          child: Center(
            child: SizedBox.square(
              dimension: logoSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ClarityColors.deepBlue.withValues(alpha: 0.24),
                      blurRadius: logoSize * 0.28,
                      spreadRadius: logoSize * 0.02,
                    ),
                    BoxShadow(
                      color: ClarityColors.tealGlow.withValues(alpha: 0.2),
                      blurRadius: logoSize * 0.34,
                      spreadRadius: logoSize * 0.01,
                    ),
                  ],
                ),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
