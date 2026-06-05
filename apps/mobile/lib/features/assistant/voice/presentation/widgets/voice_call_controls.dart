import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';

class VoiceCallControls extends StatelessWidget {
  const VoiceCallControls({
    super.key,
    required this.state,
    required this.onStart,
    required this.onEnd,
    required this.onToggleMute,
    required this.onInterrupt,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;
  final VoidCallback onInterrupt;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final canInterrupt =
        state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.thinking;

    if (state.phase == VoiceCallPhase.failed) {
      return _SubtleControlRow(
        children: [
          _QuietControlButton(
            tooltip: 'Try again',
            icon: Icons.refresh_rounded,
            label: 'Try again',
            prominent: true,
            onPressed: onRetry,
          ),
          _QuietControlButton(
            tooltip: 'Voice settings',
            icon: Icons.settings_rounded,
            label: 'Settings',
            onPressed: onOpenSettings,
          ),
        ],
      );
    }

    if (!state.isCallActive) {
      return _SubtleControlRow(
        children: [
          _QuietControlButton(
            tooltip: 'Start voice',
            icon: Icons.mic_rounded,
            label: 'Speak',
            prominent: true,
            onPressed: onStart,
          ),
        ],
      );
    }

    return _SubtleControlRow(
      children: [
        _QuietControlButton(
          tooltip: state.isMuted ? 'Unmute microphone' : 'Mute microphone',
          icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: state.isMuted ? 'Unmute' : 'Mute',
          onPressed: onToggleMute,
        ),
        _QuietControlButton(
          tooltip: 'End voice call',
          icon: Icons.call_end_rounded,
          label: 'End',
          destructive: true,
          onPressed: onEnd,
        ),
        _QuietControlButton(
          tooltip: 'Interrupt Rex',
          icon: Icons.front_hand_rounded,
          label: 'Interrupt',
          onPressed: canInterrupt ? onInterrupt : null,
        ),
      ],
    );
  }
}

class _SubtleControlRow extends StatelessWidget {
  const _SubtleControlRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: children,
    );
  }
}

class _QuietControlButton extends StatelessWidget {
  const _QuietControlButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.prominent = false,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool prominent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final foreground = destructive
        ? RexUiTokens.danger
        : prominent
        ? RexUiTokens.background
        : RexUiTokens.textMuted;
    final background = destructive
        ? RexUiTokens.danger.withValues(alpha: 0.12)
        : prominent
        ? RexUiTokens.accent
        : RexUiTokens.surfaceRaised;
    final border = destructive
        ? RexUiTokens.danger.withValues(alpha: 0.28)
        : prominent
        ? RexUiTokens.accent
        : RexUiTokens.border.withValues(alpha: 0.75);

    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: enabled
              ? background
              : RexUiTokens.surfaceRaised.withValues(alpha: 0.5),
          foregroundColor: enabled
              ? foreground
              : RexUiTokens.textSubtle.withValues(alpha: 0.42),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
            side: BorderSide(color: enabled ? border : Colors.transparent),
          ),
        ),
      ),
    );
  }
}
