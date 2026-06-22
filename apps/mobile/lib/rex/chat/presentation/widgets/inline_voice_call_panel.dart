import 'package:flutter/material.dart';

import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';

class InlineVoiceCallPanel extends StatelessWidget {
  const InlineVoiceCallPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onEnd,
    required this.onToggleMute,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final VoidCallback onRetry;
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = state.phase == VoiceCallPhase.failed;
    final transcript = state.currentTranscript.trim();
    final error = state.errorMessage?.trim();
    final statusColor = isFailed ? RexUiTokens.danger : RexUiTokens.accent;
    final statusLabel = _voiceStatusLabel(state);
    final helperText = _voiceHelperText(state);
    final visibleText = isFailed && error != null
        ? error
        : transcript.isNotEmpty
        ? transcript
        : helperText;

    return Material(
      color: RexUiTokens.background,
      elevation: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isFailed
                  ? RexUiTokens.danger.withValues(alpha: 0.10)
                  : RexUiTokens.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge),
              border: Border.all(
                color: isFailed
                    ? RexUiTokens.danger.withValues(alpha: 0.30)
                    : RexUiTokens.border.withValues(alpha: 0.72),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _VoiceActivityGlyph(
                        phase: state.phase,
                        isMuted: state.isMuted,
                        color: statusColor,
                      ),
                      const SizedBox(width: RexUiTokens.space8),
                      Expanded(
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: RexUiTokens.text,
                          ),
                        ),
                      ),
                      if (isFailed) ...[
                        IconButton(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_rounded),
                          tooltip: 'Open app settings',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                        IconButton(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Try again',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                      ] else ...[
                        IconButton(
                          onPressed: onToggleMute,
                          icon: Icon(
                            state.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                          ),
                          tooltip: state.isMuted ? 'Unmute mic' : 'Mute mic',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                      ],
                      TextButton.icon(
                        onPressed: onEnd,
                        icon: const Icon(Icons.call_end_rounded, size: 18),
                        label: const Text('End Voice'),
                        style: TextButton.styleFrom(
                          foregroundColor: RexUiTokens.danger,
                          textStyle: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ],
                  ),
                  if (visibleText.isNotEmpty) ...[
                    const SizedBox(height: RexUiTokens.space4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 72),
                      child: SingleChildScrollView(
                        child: Text(
                          visibleText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isFailed
                                ? RexUiTokens.text
                                : RexUiTokens.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _voiceStatusLabel(VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return 'Voice muted';
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => 'Voice ready',
      VoiceCallPhase.listening =>
        state.isCapturingSpeech
            ? 'Listening to you...'
            : 'Listening - you can speak',
      VoiceCallPhase.thinking => 'Rex is thinking...',
      VoiceCallPhase.speaking => 'Rex is speaking',
      VoiceCallPhase.failed => 'Voice paused',
    };
  }

  String _voiceHelperText(VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return 'Mic is muted. Tap the mic when you want to talk again.';
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => '',
      VoiceCallPhase.listening =>
        'Ready. Keep the phone in your pocket and talk naturally.',
      VoiceCallPhase.thinking => 'Got it. Rex is working on the reply.',
      VoiceCallPhase.speaking =>
        'Rex is replying. End Voice if you need to stop.',
      VoiceCallPhase.failed => 'Tap retry when you are ready to continue.',
    };
  }
}

class _VoiceActivityGlyph extends StatefulWidget {
  const _VoiceActivityGlyph({
    required this.phase,
    required this.isMuted,
    required this.color,
  });

  final VoiceCallPhase phase;
  final bool isMuted;
  final Color color;

  @override
  State<_VoiceActivityGlyph> createState() => _VoiceActivityGlyphState();
}

class _VoiceActivityGlyphState extends State<_VoiceActivityGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == VoiceCallPhase.failed) {
      return Icon(Icons.error_outline_rounded, color: widget.color, size: 20);
    }
    if (widget.isMuted && widget.phase == VoiceCallPhase.listening) {
      return Icon(Icons.mic_off_rounded, color: widget.color, size: 20);
    }
    if (widget.phase == VoiceCallPhase.thinking) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final dot = 0.36 + (_controller.value * 0.54);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < 3; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Opacity(
                    opacity: (dot - (index * 0.16)).clamp(0.22, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                      child: const SizedBox.square(dimension: 4),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < 4; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: SizedBox(
                    width: 3,
                    height:
                        8 +
                        (((index.isEven
                                    ? _controller.value
                                    : 1 - _controller.value) *
                                10)
                            .roundToDouble()),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
