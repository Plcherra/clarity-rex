import 'dart:async';

import 'package:flutter/material.dart';

class ClaritySplashScreen extends StatefulWidget {
  const ClaritySplashScreen({
    super.key,
    required this.child,
    required this.isReady,
    this.assetPath = 'assets/brand/clarity_splash_screen.png',
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF050D1A),
        child: SizedBox.expand(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
