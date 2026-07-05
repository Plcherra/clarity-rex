import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';

/// Shows pending Clarity confirmation dialogs during active voice sessions.
class VoiceClarityActionListener extends ConsumerStatefulWidget {
  const VoiceClarityActionListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VoiceClarityActionListener> createState() =>
      _VoiceClarityActionListenerState();
}

class _VoiceClarityActionListenerState
    extends ConsumerState<VoiceClarityActionListener> {
  String? _openClarityActionId;

  @override
  void initState() {
    super.initState();
    ref.listenManual<ChatState>(chatProvider, (previous, next) {
      final pending = pendingClarityActions(next.messages);
      final previousPending = previous == null
          ? const <ClarityActionCard>[]
          : pendingClarityActions(previous.messages);
      if (pending.isEmpty) {
        return;
      }
      if (previousPending.isNotEmpty &&
          pending.first.id == previousPending.first.id) {
        return;
      }
      _maybeShowClarityActionDialog(pending);
    });
  }

  void _maybeShowClarityActionDialog(List<ClarityActionCard> pending) {
    if (!mounted || pending.isEmpty) {
      return;
    }
    final action = pending.first;
    if (_openClarityActionId == action.id) {
      return;
    }
    _openClarityActionId = action.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _openClarityActionId != action.id) {
        return;
      }
      await showClarityActionConfirmationDialog(
        context,
        action: action,
        onConfirm: (confirmed) {
          ref.read(chatProvider.notifier).executeClarityAction(confirmed);
        },
        onDismiss: (dismissed) {
          ref.read(chatProvider.notifier).dismissClarityAction(dismissed);
        },
      );
      if (mounted) {
        _openClarityActionId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
