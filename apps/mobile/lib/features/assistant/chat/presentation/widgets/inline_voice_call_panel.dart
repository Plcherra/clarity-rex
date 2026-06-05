import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';

class InlineVoiceCallPanel extends StatelessWidget {
  const InlineVoiceCallPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onEnd,
    required this.onToggleMute,
    required this.onInterrupt,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final VoidCallback onRetry;
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;
  final VoidCallback onInterrupt;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = state.phase == VoiceCallPhase.failed;
    final canInterrupt =
        state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.thinking;
    final transcript = state.currentTranscript.trim();
    final error = state.errorMessage?.trim();
    final statusColor = isFailed ? RexUiTokens.danger : RexUiTokens.accent;

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
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _voiceStatusIcon(state),
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: RexUiTokens.space8),
                      Expanded(
                        child: Text(
                          _voiceStatusLabel(state),
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
                        ),
                        IconButton(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Try again',
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
                        ),
                        IconButton(
                          onPressed: canInterrupt ? onInterrupt : null,
                          icon: const Icon(Icons.front_hand_rounded),
                          tooltip: 'Interrupt Rex',
                        ),
                      ],
                      IconButton(
                        onPressed: onEnd,
                        icon: const Icon(Icons.call_end_rounded),
                        color: RexUiTokens.danger,
                        tooltip: 'End call',
                      ),
                    ],
                  ),
                  if (transcript.isNotEmpty || (isFailed && error != null)) ...[
                    const SizedBox(height: RexUiTokens.space4),
                    Text(
                      isFailed && error != null ? error : transcript,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isFailed
                            ? RexUiTokens.text
                            : RexUiTokens.textMuted,
                        height: 1.35,
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

  IconData _voiceStatusIcon(VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return Icons.mic_off_rounded;
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => Icons.call_rounded,
      VoiceCallPhase.listening => Icons.mic_rounded,
      VoiceCallPhase.thinking => Icons.more_horiz_rounded,
      VoiceCallPhase.speaking => Icons.volume_up_rounded,
      VoiceCallPhase.failed => Icons.error_outline_rounded,
    };
  }

  String _voiceStatusLabel(VoiceCallState state) {
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
}
