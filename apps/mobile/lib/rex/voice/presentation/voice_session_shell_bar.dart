import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/theme/clarity_colors.dart';

/// Persistent voice controls shown above shell navigation while a call is active
/// outside Assistant Chat (Dashboard, Accounts, Knows, etc.).
class VoiceSessionShellBar extends ConsumerWidget {
  const VoiceSessionShellBar({
    super.key,
    required this.onOpenAssistantChat,
    required this.onRetryVoice,
  });

  final VoidCallback onOpenAssistantChat;
  final VoidCallback onRetryVoice;

  static const assistantShellIndex = 3;

  static bool shouldShow({
    required VoiceCallState voice,
    required int selectedShellIndex,
    required bool assistantChatVisible,
  }) {
    if (!voice.isCallActive && voice.phase != VoiceCallPhase.failed) {
      return false;
    }
    return selectedShellIndex != assistantShellIndex || !assistantChatVisible;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceCallProvider);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final controller = ref.read(voiceCallProvider.notifier);

    return Material(
      elevation: 6,
      color: colors.surfaceElevated,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpenAssistantChat,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: colors.accent),
                    const SizedBox(width: RexUiTokens.space8),
                    Expanded(
                      child: Text(
                        l10n.voiceSessionReturnToChat,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                  ],
                ),
              ),
            ),
            InlineVoiceCallPanel(
              state: voice,
              onRetry: onRetryVoice,
              onEnd: () async => controller.endCall(),
              onToggleMute: controller.toggleMuted,
              onOpenSettings: () async {
                if (AppCapabilities.instance.isWeb) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.voiceErrorMicBrowserSettings)),
                  );
                  return;
                }
                await controller.openVoiceSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
