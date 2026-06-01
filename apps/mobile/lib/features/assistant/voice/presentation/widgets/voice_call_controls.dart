import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final canInterrupt =
        state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.thinking;

    if (state.phase == VoiceCallPhase.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try voice again'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Settings'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEnd,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (!state.isCallActive) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.call_rounded),
        label: const Text('Start voice'),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundCallButton(
              tooltip: state.isMuted ? 'Unmute mic' : 'Mute mic',
              icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: state.isMuted ? 'Unmute' : 'Mute',
              onPressed: onToggleMute,
            ),
            const SizedBox(width: 12),
            _RoundCallButton(
              tooltip: 'End call',
              icon: Icons.call_end_rounded,
              label: 'End',
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              onPressed: onEnd,
              size: 68,
            ),
            const SizedBox(width: 12),
            _RoundCallButton(
              tooltip: 'Interrupt Rex',
              icon: Icons.front_hand_rounded,
              label: 'Pause',
              onPressed: canInterrupt ? onInterrupt : null,
              onLongPress: canInterrupt ? onInterrupt : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 58,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
              child: IconButton.filled(
                onPressed: onPressed,
                onLongPress: onLongPress,
                style: IconButton.styleFrom(
                  backgroundColor:
                      backgroundColor ?? scheme.surfaceContainerHighest,
                  foregroundColor: foregroundColor ?? scheme.onSurface,
                  disabledBackgroundColor: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  disabledForegroundColor: scheme.onSurfaceVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
                icon: Icon(icon),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: onPressed == null
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
