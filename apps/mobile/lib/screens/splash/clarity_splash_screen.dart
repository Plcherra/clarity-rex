import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/clarity_colors.dart';
import '../../theme/clarity_theme.dart';
import '../../widgets/clarity_diamond_loader.dart';

class ClaritySplashScreen extends StatefulWidget {
  const ClaritySplashScreen({
    super.key,
    required this.child,
    required this.isReady,
    this.logoAssetPath = 'assets/brand/splash_logo.png',
    this.fallbackLogoAssetPath = 'assets/brand/clarity_mark.png',
    this.minDuration = const Duration(milliseconds: 600),
    this.fadeDuration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final bool isReady;
  final String logoAssetPath;
  final String fallbackLogoAssetPath;
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
                child: _SplashVisual(
                  logoAssetPath: widget.logoAssetPath,
                  fallbackLogoAssetPath: widget.fallbackLogoAssetPath,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashVisual extends StatelessWidget {
  const _SplashVisual({
    required this.logoAssetPath,
    required this.fallbackLogoAssetPath,
  });

  final String logoAssetPath;
  final String fallbackLogoAssetPath;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ClarityTheme.dark(),
        child: Material(
          color: ClarityColors.appBackground,
          child: Center(
            child: _SplashLogo(
              logoAssetPath: logoAssetPath,
              fallbackLogoAssetPath: fallbackLogoAssetPath,
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({
    required this.logoAssetPath,
    required this.fallbackLogoAssetPath,
  });

  final String logoAssetPath;
  final String fallbackLogoAssetPath;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeOf(context)?.size ?? const Size(390, 844);
    final shortestSide = size.shortestSide;
    final logoSize = (shortestSide * 0.42).clamp(148.0, 220.0);

    return SizedBox.square(
      dimension: logoSize,
      child: Image.asset(
        logoAssetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            fallbackLogoAssetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return const ClarityDiamondLoader();
            },
          );
        },
      ),
    );
  }
}
