import 'package:flutter/material.dart';

import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_generic_action_card.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_person_confirm_card.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

/// Confirm/dismiss cards for pending Clarity write proposals.
class ClarityActionCardsStrip extends StatelessWidget {
  const ClarityActionCardsStrip({
    super.key,
    required this.actions,
    this.onConfirm,
    this.onDismiss,
  });

  final List<ClarityActionCard> actions;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: RexUiTokens.confirmCardGap),
            child: _buildActionCard(action),
          ),
      ],
    );
  }

  Widget _buildActionCard(ClarityActionCard action) {
    if (action.personCard != null) {
      return ClarityPersonConfirmCard(
        action: action,
        onConfirm: onConfirm,
        onDismiss: onDismiss,
      );
    }
    return ClarityGenericActionCard(
      action: action,
      onConfirm: onConfirm,
      onDismiss: onDismiss,
    );
  }
}

List<ClarityActionCard> pendingClarityActions(Iterable<ChatMessage> messages) {
  final seenIds = <String>{};
  for (final message in messages.toList().reversed) {
    if (message.role != ChatMessageRole.assistant) {
      continue;
    }
    final pending = <ClarityActionCard>[];
    for (final action in message.clarityActions) {
      if (action.status != 'pending') {
        continue;
      }
      if (action.id.isEmpty || seenIds.add(action.id)) {
        pending.add(action);
      }
    }
    if (pending.isNotEmpty) {
      return List.unmodifiable(pending);
    }
  }
  return const [];
}

Future<void> showClarityActionConfirmationDialog(
  BuildContext context, {
  required ClarityActionCard action,
  ValueChanged<ClarityActionCard>? onConfirm,
  ValueChanged<ClarityActionCard>? onDismiss,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: action.canDismiss,
    builder: (dialogContext) {
      void Function(ClarityActionCard)? wrapConfirm;
      void Function(ClarityActionCard)? wrapDismiss;
      if (onConfirm != null) {
        wrapConfirm = (confirmed) {
          Navigator.of(dialogContext).pop();
          onConfirm(confirmed);
        };
      }
      if (onDismiss != null) {
        wrapDismiss = (dismissed) {
          Navigator.of(dialogContext).pop();
          onDismiss(dismissed);
        };
      }
      return SafeArea(
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: RexUiTokens.space16,
            vertical: RexUiTokens.space16,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RexUiTokens.confirmCardRadius),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RexUiTokens.confirmCardPadding),
              child: action.personCard != null
                  ? ClarityPersonConfirmCard(
                      action: action,
                      onConfirm: wrapConfirm,
                      onDismiss: wrapDismiss,
                    )
                  : ClarityGenericActionCard(
                      action: action,
                      onConfirm: wrapConfirm,
                      onDismiss: wrapDismiss,
                    ),
            ),
          ),
        ),
      );
    },
  );
}
