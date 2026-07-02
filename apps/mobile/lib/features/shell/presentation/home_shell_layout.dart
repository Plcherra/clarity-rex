import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/finance_content_constraints.dart';
import '../../../rex/presentation/assistant_chat_visible_provider.dart';
import '../../../rex/voice/application/voice_call_controller.dart';
import '../../../rex/voice/presentation/voice_session_shell_bar.dart';

export '../../../core/layout/finance_content_constraints.dart';

/// Adaptive shell navigation: bottom bar below [homeShellCompactBreakpoint],
/// [NavigationRail] at wider widths.
class HomeShellAdaptiveScaffold extends ConsumerWidget {
  const HomeShellAdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.railDestinations,
    required this.body,
    this.onOpenAssistantChat,
    this.onRetryVoice,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final List<NavigationRailDestination> railDestinations;
  final Widget body;
  final VoidCallback? onOpenAssistantChat;
  final VoidCallback? onRetryVoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = isHomeShellCompactWidth(context);
    final voice = ref.watch(voiceCallProvider);
    final assistantChatVisible = ref.watch(assistantChatVisibleProvider);
    final showVoiceBar =
        onOpenAssistantChat != null &&
        onRetryVoice != null &&
        VoiceSessionShellBar.shouldShow(
          voice: voice,
          selectedShellIndex: selectedIndex,
          assistantChatVisible: assistantChatVisible,
        );
    final voiceFooter = showVoiceBar
        ? VoiceSessionShellBar(
            onOpenAssistantChat: onOpenAssistantChat!,
            onRetryVoice: onRetryVoice!,
          )
        : null;

    if (compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?voiceFooter,
            NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: railDestinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: body),
                ?voiceFooter,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
