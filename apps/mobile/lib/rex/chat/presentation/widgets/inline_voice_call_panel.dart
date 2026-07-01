import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_diamond_loader.dart';

/// Inline live transcript shown at the bottom of the chat scroll area.
class VoiceLiveTranscript extends StatelessWidget {
  const VoiceLiveTranscript({super.key, required this.state});

  final VoiceCallState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final isFailed = state.phase == VoiceCallPhase.failed;
    final transcript = state.currentTranscript.trim();
    final visibleText = isFailed
        ? voiceFailureMessage(l10n, state.errorMessage)
        : transcript;

    if (isFailed) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(
          visibleText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
            height: 1.45,
          ),
        ),
      );
    }

    if (visibleText.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(
          visibleText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.textSecondary,
            height: 1.45,
          ),
        ),
      );
    }

    if (state.phase == VoiceCallPhase.listening && !state.isMuted) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Row(
          children: [
            _VoiceWaveIndicator(
              phase: state.phase,
              color: colors.textMuted,
              compact: true,
            ),
            const SizedBox(width: RexUiTokens.space8),
            Text(
              l10n.voicePanelStartTalking,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (state.phase == VoiceCallPhase.thinking) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(
          l10n.voicePanelProcessing,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textMuted,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Compact voice controls above the composer — flat icons, no overlay box.
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
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final isFailed = state.phase == VoiceCallPhase.failed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Row(
        children: [
          Semantics(
            label: _voiceSemanticLabel(l10n, state),
            liveRegion: true,
            child: _VoiceWaveIndicator(
              phase: state.phase,
              isMuted: state.isMuted,
              color: isFailed ? colors.danger : colors.accent,
              isFailed: isFailed,
            ),
          ),
          const SizedBox(width: RexUiTokens.space8),
          if (state.isMuted && !isFailed)
            Text(
              l10n.voicePanelMuted,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          if (isFailed) ...[
            _VoiceFlatIconButton(
              icon: Icons.settings_outlined,
              tooltip: l10n.voicePanelSettingsTooltip,
              onPressed: onOpenSettings,
            ),
            const SizedBox(width: RexUiTokens.space4),
            _VoiceFlatIconButton(
              icon: Icons.refresh_rounded,
              tooltip: l10n.voicePanelTryAgainTooltip,
              onPressed: onRetry,
            ),
            const SizedBox(width: RexUiTokens.space4),
          ] else ...[
            _VoiceFlatIconButton(
              icon: state.isMuted ? Icons.mic_off_outlined : Icons.mic_none_outlined,
              tooltip: state.isMuted
                  ? l10n.voicePanelUnmuteMicTooltip
                  : l10n.voicePanelMuteMicTooltip,
              onPressed: onToggleMute,
            ),
            const SizedBox(width: RexUiTokens.space4),
          ],
          _VoiceFlatIconButton(
            icon: Icons.stop_rounded,
            tooltip: l10n.voicePanelEndVoiceTooltip,
            onPressed: onEnd,
            foregroundColor: colors.danger,
          ),
        ],
      ),
    );
  }

  String _voiceSemanticLabel(AppLocalizations l10n, VoiceCallState state) {
    if (state.isMuted && state.phase == VoiceCallPhase.listening) {
      return l10n.voicePanelVoiceMuted;
    }
    return switch (state.phase) {
      VoiceCallPhase.idle => l10n.voicePanelVoiceReady,
      VoiceCallPhase.listening => l10n.voicePanelListening,
      VoiceCallPhase.thinking => l10n.voicePanelThinking,
      VoiceCallPhase.speaking => l10n.voicePanelSpeaking,
      VoiceCallPhase.failed => l10n.voicePanelVoicePaused,
    };
  }
}

class _VoiceFlatIconButton extends StatelessWidget {
  const _VoiceFlatIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        fixedSize: const Size.square(40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.transparent,
        foregroundColor: foregroundColor ?? colors.textSecondary,
        shadowColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

class _VoiceWaveIndicator extends StatefulWidget {
  const _VoiceWaveIndicator({
    required this.phase,
    required this.color,
    this.isMuted = false,
    this.isFailed = false,
    this.compact = false,
  });

  final VoiceCallPhase phase;
  final Color color;
  final bool isMuted;
  final bool isFailed;
  final bool compact;

  @override
  State<_VoiceWaveIndicator> createState() => _VoiceWaveIndicatorState();
}

class _VoiceWaveIndicatorState extends State<_VoiceWaveIndicator>
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
    if (widget.isFailed) {
      return Icon(Icons.error_outline_rounded, color: widget.color, size: 20);
    }
    if (widget.isMuted && widget.phase == VoiceCallPhase.listening) {
      return Icon(Icons.mic_off_outlined, color: widget.color, size: 20);
    }
    if (widget.phase == VoiceCallPhase.thinking) {
      return ClarityDiamondLoader(size: widget.compact ? 16 : 20);
    }
    if (widget.phase == VoiceCallPhase.speaking) {
      return Icon(Icons.volume_up_outlined, color: widget.color, size: 20);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < (widget.compact ? 3 : 4); index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: SizedBox(
                    width: 2.5,
                    height:
                        (widget.compact ? 6 : 8) +
                        (((index.isEven
                                    ? _controller.value
                                    : 1 - _controller.value) *
                                (widget.compact ? 8 : 10))
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

String voiceFailureMessage(AppLocalizations l10n, String? error) {
  final message = error?.trim();
  if (message == null || message.isEmpty) {
    return l10n.voiceFailurePausedDefault;
  }
  final remapped = _remapLegacyEnglishVoiceFailure(l10n, message);
  return remapped ?? message;
}

String? _remapLegacyEnglishVoiceFailure(AppLocalizations l10n, String error) {
  final message = error.toLowerCase();
  if (message.contains('auth') ||
      message.contains('token') ||
      message.contains('session') ||
      message.contains('expired') ||
      message.contains('unauthorized') ||
      message.contains('401')) {
    return l10n.voiceFailureSessionReconnect;
  }
  if (message.contains('permission') ||
      message.contains('capture') ||
      message.contains('microphone') ||
      message.contains('microphone access') ||
      message.contains('settings')) {
    return l10n.voiceFailureMicrophoneAccess;
  }
  if (message.contains('secure connection') ||
      message.contains('https://') ||
      message.contains('insecure')) {
    return l10n.voiceErrorMicInsecureContext;
  }
  if (message.contains('empty_audio') ||
      message.contains('no audio') ||
      message.contains('did not catch') ||
      message.contains('did not hear') ||
      message.contains('blank transcript')) {
    return l10n.voiceFailureDidNotCatch;
  }
  if (message.contains('disconnect') ||
      message.contains('connection') ||
      message.contains('socket') ||
      message.contains('stream')) {
    return l10n.voiceFailureConnectionDropped;
  }
  if (message.contains('transcript')) {
    return l10n.voiceFailureTranscriptUnreadable;
  }
  if (message.contains('tts') ||
      message.contains('synthesize') ||
      message.contains('playback') ||
      message.contains('play rex voice') ||
      message.contains('play audio')) {
    return l10n.voiceFailurePlaybackFailed;
  }
  return null;
}
