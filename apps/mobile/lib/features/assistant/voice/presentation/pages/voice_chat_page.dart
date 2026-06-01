import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/assistant/assistant_providers.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';
import 'package:clarity/features/assistant/voice/presentation/widgets/voice_call_controls.dart';

class VoiceChatPage extends ConsumerWidget {
  const VoiceChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceCallProvider);
    final voiceController = ref.read(voiceCallProvider.notifier);
    final chat = ref.watch(chatProvider);
    final currentConversation = ref.watch(currentConversationProvider);
    final conversationTitle = currentConversation?.title ?? 'Current chat';

    Future<void> startCall() async {
      final started = await voiceController.startCall(
        conversationId: chat.conversationId,
      );
      if (!context.mounted || started) {
        return;
      }
      final message =
          ref.read(voiceCallProvider).errorMessage ??
          'Could not start Rex voice.';
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 20,
                8,
                compact ? 16 : 20,
                24,
              ),
              sliver: SliverToBoxAdapter(
                child: voice.isCallActive
                    ? _ActiveVoiceSurface(
                        state: voice,
                        conversationTitle: conversationTitle,
                        onRetry: startCall,
                        onEnd: voiceController.endCall,
                        onToggleMute: voiceController.toggleMuted,
                        onInterrupt: () => voiceController.interruptAndListen(
                          reason: 'Rex was interrupted.',
                        ),
                        onOpenSettings: voiceController.openVoiceSettings,
                      )
                    : _IdleVoiceSurface(
                        state: voice,
                        conversationTitle: conversationTitle,
                        onStart: startCall,
                        onRetry: startCall,
                        onEnd: voiceController.endCall,
                        onOpenSettings: voiceController.openVoiceSettings,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IdleVoiceSurface extends StatelessWidget {
  const _IdleVoiceSurface({
    required this.state,
    required this.conversationTitle,
    required this.onStart,
    required this.onRetry,
    required this.onEnd,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final String conversationTitle;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final VoidCallback onEnd;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = state.phase == VoiceCallPhase.failed;
    final error = state.errorMessage?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VoiceStatusHeader(
          eyebrow: failed ? 'Voice needs attention' : 'Rex Voice',
          title: failed ? 'Voice could not start' : 'Talk with Rex',
          subtitle: failed && error != null
              ? error
              : 'Continue the same conversation by voice.',
          icon: failed ? Icons.error_outline_rounded : Icons.graphic_eq_rounded,
          tone: failed ? _VoiceTone.error : _VoiceTone.ready,
        ),
        const SizedBox(height: 16),
        _ConversationContextCard(title: conversationTitle),
        const SizedBox(height: 22),
        _VoicePresence(
          state: state,
          label: failed ? 'Ready to retry' : 'Voice ready',
        ),
        const SizedBox(height: 24),
        VoiceCallControls(
          state: state,
          onStart: onStart,
          onEnd: onEnd,
          onToggleMute: () {},
          onInterrupt: () {},
          onRetry: onRetry,
          onOpenSettings: onOpenSettings,
        ),
        if (failed) ...[
          const SizedBox(height: 12),
          Text(
            'Check microphone permission if this keeps happening.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveVoiceSurface extends StatelessWidget {
  const _ActiveVoiceSurface({
    required this.state,
    required this.conversationTitle,
    required this.onRetry,
    required this.onEnd,
    required this.onToggleMute,
    required this.onInterrupt,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final String conversationTitle;
  final VoidCallback onRetry;
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;
  final VoidCallback onInterrupt;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VoiceStatusHeader(
          eyebrow: _phaseEyebrow(state),
          title: _phaseTitle(state),
          subtitle: _phaseSubtitle(state),
          icon: _phaseIcon(state),
          tone: _toneForPhase(state),
          trailing: _CallDurationLabel(state: state),
        ),
        const SizedBox(height: 16),
        _ConversationContextCard(title: conversationTitle),
        const SizedBox(height: 18),
        _VoicePresence(state: state, label: _phaseShortLabel(state)),
        const SizedBox(height: 18),
        _TranscriptPanel(
          title: 'You',
          icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          text: state.currentTranscript.trim(),
          emptyText: state.isMuted
              ? 'Microphone muted.'
              : state.phase == VoiceCallPhase.listening
              ? 'Listening for your next thought.'
              : 'No new transcript yet.',
        ),
        const SizedBox(height: 12),
        _TranscriptPanel(
          title: 'Rex',
          icon: Icons.auto_awesome_rounded,
          text: state.lastAssistantResponse.trim(),
          emptyText: state.phase == VoiceCallPhase.thinking
              ? 'Rex is working through it.'
              : 'Rex response will appear here.',
        ),
        const SizedBox(height: 22),
        VoiceCallControls(
          state: state,
          onStart: () {},
          onEnd: onEnd,
          onToggleMute: onToggleMute,
          onInterrupt: onInterrupt,
          onRetry: onRetry,
          onOpenSettings: onOpenSettings,
        ),
      ],
    );
  }
}

class _VoiceStatusHeader extends StatelessWidget {
  const _VoiceStatusHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final _VoiceTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _toneColor(scheme, tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: accent, size: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ConversationContextCard extends StatelessWidget {
  const _ConversationContextCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePresence extends StatelessWidget {
  const _VoicePresence({required this.state, required this.label});

  final VoiceCallState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = _toneForPhase(state);
    final accent = _toneColor(scheme, tone);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: Center(
              child: _VoiceMeter(phase: state.phase, color: accent),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceMeter extends StatelessWidget {
  const _VoiceMeter({required this.phase, required this.color});

  final VoiceCallPhase phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active =
        phase != VoiceCallPhase.idle && phase != VoiceCallPhase.failed;
    final heights = switch (phase) {
      VoiceCallPhase.listening => const [28.0, 58.0, 84.0, 52.0, 34.0],
      VoiceCallPhase.thinking => const [32.0, 42.0, 54.0, 42.0, 32.0],
      VoiceCallPhase.speaking => const [54.0, 82.0, 48.0, 74.0, 42.0],
      VoiceCallPhase.failed => const [34.0, 34.0, 34.0, 34.0, 34.0],
      VoiceCallPhase.idle => const [40.0, 40.0, 40.0, 40.0, 40.0],
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final (index, height) in heights.indexed) ...[
          AnimatedContainer(
            duration: Duration(milliseconds: 240 + index * 35),
            curve: Curves.easeOutCubic,
            width: 12,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.76 : 0.34),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (index != heights.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({
    required this.title,
    required this.icon,
    required this.text,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final String text;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasText = text.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasText ? text : emptyText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasText ? scheme.onSurface : scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallDurationLabel extends ConsumerWidget {
  const _CallDurationLabel({required this.state});

  final VoiceCallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(voiceCallNowProvider);
    final duration = state.callDuration(now: now());
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          _formatDuration(duration),
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

enum _VoiceTone { ready, listening, thinking, speaking, error }

_VoiceTone _toneForPhase(VoiceCallState state) {
  if (state.isMuted && state.phase == VoiceCallPhase.listening) {
    return _VoiceTone.thinking;
  }
  return switch (state.phase) {
    VoiceCallPhase.idle => _VoiceTone.ready,
    VoiceCallPhase.listening => _VoiceTone.listening,
    VoiceCallPhase.thinking => _VoiceTone.thinking,
    VoiceCallPhase.speaking => _VoiceTone.speaking,
    VoiceCallPhase.failed => _VoiceTone.error,
  };
}

Color _toneColor(ColorScheme scheme, _VoiceTone tone) {
  return switch (tone) {
    _VoiceTone.ready => scheme.primary,
    _VoiceTone.listening => const Color(0xFF1D7C57),
    _VoiceTone.thinking => const Color(0xFF6B5A2E),
    _VoiceTone.speaking => const Color(0xFF345F8C),
    _VoiceTone.error => scheme.error,
  };
}

IconData _phaseIcon(VoiceCallState state) {
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

String _phaseEyebrow(VoiceCallState state) {
  if (state.isMuted && state.phase == VoiceCallPhase.listening) {
    return 'Microphone muted';
  }
  return switch (state.phase) {
    VoiceCallPhase.idle => 'Voice ready',
    VoiceCallPhase.listening => 'Listening',
    VoiceCallPhase.thinking => 'Thinking',
    VoiceCallPhase.speaking => 'Speaking',
    VoiceCallPhase.failed => 'Voice needs attention',
  };
}

String _phaseTitle(VoiceCallState state) {
  if (state.isMuted && state.phase == VoiceCallPhase.listening) {
    return 'Rex is waiting';
  }
  return switch (state.phase) {
    VoiceCallPhase.idle => 'Talk with Rex',
    VoiceCallPhase.listening => 'Rex is listening',
    VoiceCallPhase.thinking => 'Rex is thinking',
    VoiceCallPhase.speaking => 'Rex is speaking',
    VoiceCallPhase.failed => 'Voice could not start',
  };
}

String _phaseSubtitle(VoiceCallState state) {
  if (state.isMuted && state.phase == VoiceCallPhase.listening) {
    return 'Unmute when you are ready to continue.';
  }
  return switch (state.phase) {
    VoiceCallPhase.idle => 'Continue the same conversation by voice.',
    VoiceCallPhase.listening => 'Speak naturally. Rex will keep the context.',
    VoiceCallPhase.thinking => 'Rex is preparing a response.',
    VoiceCallPhase.speaking => 'Rex is answering out loud.',
    VoiceCallPhase.failed => state.errorMessage ?? 'Voice needs attention.',
  };
}

String _phaseShortLabel(VoiceCallState state) {
  if (state.isMuted && state.phase == VoiceCallPhase.listening) {
    return 'Muted';
  }
  return switch (state.phase) {
    VoiceCallPhase.idle => 'Voice ready',
    VoiceCallPhase.listening =>
      state.isCapturingSpeech ? 'Hearing you' : 'Listening',
    VoiceCallPhase.thinking => 'Thinking',
    VoiceCallPhase.speaking => 'Speaking',
    VoiceCallPhase.failed => 'Needs attention',
  };
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
