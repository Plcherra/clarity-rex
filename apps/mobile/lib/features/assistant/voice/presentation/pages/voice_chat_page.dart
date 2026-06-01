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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
        child: Column(
          children: [
            Expanded(
              child: _MinimalVoiceBody(
                state: voice,
                onStart: startCall,
                onRetry: startCall,
                onOpenSettings: voiceController.openVoiceSettings,
              ),
            ),
            VoiceCallControls(
              state: voice,
              onStart: startCall,
              onEnd: voiceController.endCall,
              onToggleMute: voiceController.toggleMuted,
              onInterrupt: () => voiceController.interruptAndListen(
                reason: 'Rex was interrupted.',
              ),
              onRetry: startCall,
              onOpenSettings: voiceController.openVoiceSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalVoiceBody extends StatelessWidget {
  const _MinimalVoiceBody({
    required this.state,
    required this.onStart,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoiceCallState state;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final transcript = state.currentTranscript.trim();
    final response = state.lastAssistantResponse.trim();
    final error = state.errorMessage?.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: state.canStartCall ? onStart : null,
      child: Column(
        children: [
          const Spacer(flex: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: Text(
              _statusText(state),
              key: ValueKey('${state.phase}-${state.isMuted}'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: state.phase == VoiceCallPhase.failed
                    ? scheme.error
                    : scheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _QuietPulse(active: state.isCallActive, phase: state.phase),
          const SizedBox(height: 36),
          _PlainVoiceText(
            text: transcript,
            fallback: state.phase == VoiceCallPhase.listening && !state.isMuted
                ? ''
                : null,
            color: scheme.onSurface,
            style: theme.textTheme.titleMedium,
          ),
          if (response.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PlainVoiceText(
              text: response,
              color: scheme.onSurfaceVariant,
              style: theme.textTheme.bodyLarge,
            ),
          ],
          if (state.phase == VoiceCallPhase.failed && error != null) ...[
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                TextButton(onPressed: onRetry, child: const Text('Try again')),
                TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _PlainVoiceText extends StatelessWidget {
  const _PlainVoiceText({
    required this.text,
    required this.color,
    this.style,
    this.fallback,
  });

  final String text;
  final String? fallback;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final value = text.isNotEmpty ? text : fallback;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: value == null || value.isEmpty
          ? const SizedBox.shrink()
          : Text(
              value,
              key: ValueKey(value),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(color: color, height: 1.35),
            ),
    );
  }
}

class _QuietPulse extends StatelessWidget {
  const _QuietPulse({required this.active, required this.phase});

  final bool active;
  final VoiceCallPhase phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = phase == VoiceCallPhase.failed
        ? scheme.error
        : scheme.primary.withValues(alpha: active ? 0.72 : 0.34);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.65, end: active ? 1 : 0.65),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: active ? 0.16 : 0.10),
            ),
            child: SizedBox.square(
              dimension: 18,
              child: Center(
                child: SizedBox.square(
                  dimension: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _statusText(VoiceCallState state) {
  if (state.isMuted && state.phase == VoiceCallPhase.listening) {
    return 'Muted';
  }
  return switch (state.phase) {
    VoiceCallPhase.idle => 'Tap to speak',
    VoiceCallPhase.listening => 'Listening...',
    VoiceCallPhase.thinking => 'Rex is thinking...',
    VoiceCallPhase.speaking => 'Rex is speaking...',
    VoiceCallPhase.failed => 'Voice paused',
  };
}
