import 'package:flutter/material.dart';

import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_diamond_loader.dart';

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
    final colors = context.clarityColors;
    final isFailed = state.phase == VoiceCallPhase.failed;
    final transcript = state.currentTranscript.trim();
    final error = state.errorMessage?.trim();
    final statusColor = isFailed ? colors.danger : colors.accent;
    final statusLabel = _voiceSemanticLabel(state);
    final visibleText = isFailed ? _voiceFailureMessage(error) : transcript;
    final hasVisibleText = visibleText.isNotEmpty;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isFailed
                  ? colors.danger.withValues(alpha: 0.10)
                  : colors.surfaceElevated.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge + 2),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: statusLabel,
                        liveRegion: true,
                        child: _VoiceActivityOrb(
                          phase: state.phase,
                          isMuted: state.isMuted,
                          color: statusColor,
                          isFailed: isFailed,
                        ),
                      ),
                      const Spacer(),
                      if (state.isMuted && !isFailed) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: RexUiTokens.surfaceRaised.withValues(
                              alpha: 0.72,
                            ),
                            borderRadius: BorderRadius.circular(
                              RexUiTokens.radiusPill,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Text(
                              'Muted',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: RexUiTokens.space4),
                      ],
                      if (!isFailed)
                        IconButton(
                          onPressed: onToggleMute,
                          icon: Icon(
                            state.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                          ),
                          tooltip: state.isMuted ? 'Unmute mic' : 'Mute mic',
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(40),
                            fixedSize: const Size.square(40),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: colors.surfaceSoft.withValues(
                              alpha: 0.58,
                            ),
                            foregroundColor: state.isMuted
                                ? colors.textSecondary
                                : colors.textPrimary,
                          ),
                        ),
                      const SizedBox(width: RexUiTokens.space4),
                      IconButton(
                        onPressed: onEnd,
                        icon: const Icon(Icons.call_end_rounded, size: 20),
                        tooltip: 'End voice',
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(40),
                          fixedSize: const Size.square(40),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: colors.danger.withValues(
                            alpha: 0.16,
                          ),
                          foregroundColor: colors.danger,
                        ),
                      ),
                    ],
                  ),
                  if (hasVisibleText) ...[
                    const SizedBox(height: RexUiTokens.space8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: isFailed
                            ? colors.danger.withValues(alpha: 0.08)
                            : colors.background.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(
                          RexUiTokens.radiusMedium,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 72),
                          child: SingleChildScrollView(
                            child: Text(
                              visibleText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isFailed
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isFailed) ...[
                    const SizedBox(height: RexUiTokens.space8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_rounded, size: 18),
                          label: const Text('Settings'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            side: BorderSide(color: colors.divider),
                            textStyle: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: RexUiTokens.space8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try again'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                              textStyle: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  String _voiceSemanticLabel(VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return 'Voice muted';
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => 'Voice ready',
      VoiceCallPhase.listening => 'Listening',
      VoiceCallPhase.thinking => 'Thinking',
      VoiceCallPhase.speaking => 'Speaking',
      VoiceCallPhase.failed => 'Voice paused',
    };
  }

  String _voiceFailureMessage(String? error) {
    final message = error?.toLowerCase() ?? '';
    if (message.contains('permission') ||
        message.contains('microphone access') ||
        message.contains('settings')) {
      return 'Microphone access is needed for voice. Check Settings, then try again.';
    }
    if (message.contains('empty_audio') ||
        message.contains('no audio') ||
        message.contains('did not catch') ||
        message.contains('blank transcript')) {
      return "I didn't catch that. Tap Try again when you are ready.";
    }
    if (message.contains('disconnect') ||
        message.contains('connection') ||
        message.contains('socket') ||
        message.contains('stream')) {
      return 'Voice connection dropped. Tap Try again to reconnect.';
    }
    if (message.contains('transcript')) {
      return "I couldn't read that transcript. Tap Try again and say it once more.";
    }
    return 'Voice paused. Tap Try again when you are ready to continue.';
  }
}

class _VoiceActivityOrb extends StatelessWidget {
  const _VoiceActivityOrb({
    required this.phase,
    required this.isMuted,
    required this.color,
    required this.isFailed,
  });

  final VoiceCallPhase phase;
  final bool isMuted;
  final Color color;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFailed
            ? colors.danger.withValues(alpha: 0.12)
            : colors.accent.withValues(alpha: 0.10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isFailed ? 0.08 : 0.12),
            blurRadius: 18,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 46,
        child: Center(
          child: _VoiceActivityGlyph(
            phase: phase,
            isMuted: isMuted,
            color: color,
          ),
        ),
      ),
    );
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
      return const ClarityDiamondLoader(size: 24);
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
