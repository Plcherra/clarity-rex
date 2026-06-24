import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../theme/clarity_colors.dart';
import '../../theme/clarity_theme.dart';
import '../../widgets/clarity_diamond_loader.dart';

class ClaritySplashScreen extends StatefulWidget {
  const ClaritySplashScreen({
    super.key,
    required this.child,
    required this.isReady,
    this.assetPath = 'assets/videos/splashscreen.mp4',
    this.minFallbackDuration = const Duration(milliseconds: 900),
    this.videoInitTimeout = const Duration(milliseconds: 2500),
    this.fadeDuration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final bool isReady;
  final String assetPath;
  final Duration minFallbackDuration;
  final Duration videoInitTimeout;
  final Duration fadeDuration;

  @override
  State<ClaritySplashScreen> createState() => _ClaritySplashScreenState();
}

class _ClaritySplashScreenState extends State<ClaritySplashScreen> {
  VideoPlayerController? _videoController;
  Timer? _fallbackTimer;
  Timer? _videoCompletionSafetyTimer;
  var _videoReady = false;
  var _videoFailed = false;
  var _videoComplete = false;
  var _fallbackMinElapsed = false;
  var _overlayVisible = true;
  var _overlayMounted = true;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(widget.minFallbackDuration, () {
      if (!mounted) return;
      setState(() => _fallbackMinElapsed = true);
      _maybeDismissOverlay();
    });
    unawaited(_initializeVideo());
  }

  @override
  void didUpdateWidget(covariant ClaritySplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady != oldWidget.isReady) {
      _maybeDismissOverlay();
    }
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset(
      widget.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _videoController = controller;

    try {
      await controller.initialize().timeout(widget.videoInitTimeout);
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_handleVideoProgress);
      final duration = controller.value.duration;
      _videoCompletionSafetyTimer = Timer(
        duration > Duration.zero
            ? duration + const Duration(milliseconds: 350)
            : widget.minFallbackDuration,
        _markVideoComplete,
      );
      setState(() {
        _videoReady = true;
        _videoComplete = duration <= Duration.zero;
      });
      _maybeDismissOverlay();
      unawaited(controller.play());
    } on Object {
      if (!mounted) return;
      if (identical(_videoController, controller)) {
        _videoController = null;
      }
      await controller.dispose();
      if (!mounted) return;
      setState(() => _videoFailed = true);
      _maybeDismissOverlay();
    }
  }

  void _handleVideoProgress() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero && position >= duration) {
      _markVideoComplete();
    }
  }

  void _markVideoComplete() {
    if (!mounted || _videoComplete) return;
    setState(() => _videoComplete = true);
    _maybeDismissOverlay();
  }

  void _maybeDismissOverlay() {
    if (!_overlayVisible || !widget.isReady) return;

    final canDismiss = _videoReady
        ? _videoComplete
        : _videoFailed && _fallbackMinElapsed;
    if (!canDismiss) return;

    setState(() => _overlayVisible = false);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoCompletionSafetyTimer?.cancel();
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_handleVideoProgress);
      unawaited(controller.dispose());
    }
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
                child: _SplashVisual(controller: _videoController),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashVisual extends StatelessWidget {
  const _SplashVisual({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final videoReady = controller?.value.isInitialized ?? false;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ClarityTheme.dark(),
        child: Material(
          color: ClarityColors.appBackground,
          child: Center(
            child: videoReady
                ? _SplashVideo(controller: controller!)
                : const ClarityDiamondLoader(),
          ),
        ),
      ),
    );
  }
}

class _SplashVideo extends StatelessWidget {
  const _SplashVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeOf(context)?.size ?? const Size(390, 844);
    final shortestSide = size.shortestSide;
    final maxLogoSize = (shortestSide * 0.42).clamp(148.0, 220.0);
    final aspectRatio = controller.value.aspectRatio;

    return SizedBox(
      width: maxLogoSize,
      child: AspectRatio(
        aspectRatio: aspectRatio <= 0 ? 1 : aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}
