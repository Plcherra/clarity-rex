import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/layout/web_centered_dialog.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';
import 'package:clarity/theme/clarity_colors.dart';

Future<void> renameConversationFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
}) async {
  final l10n = context.l10n;
  final controller = TextEditingController(
    text: conversation.title?.trim().isNotEmpty == true
        ? conversation.title!.trim()
        : conversationTitle(l10n, conversation),
  );
  try {
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => wrapWebCenteredDialog(
        dialogContext,
        AlertDialog(
          title: Text(l10n.conversationListRenameTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            maxLength: kConversationTitleMaxLength,
            decoration: InputDecoration(
              labelText: l10n.conversationListRenameHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );

    if (nextTitle == null || nextTitle.isEmpty) {
      return;
    }

    final renamed = await ref
        .read(conversationListProvider.notifier)
        .renameConversation(
          conversationId: conversation.id,
          title: nextTitle,
        );

    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!renamed) {
      final errorMessage =
          ref.read(conversationListProvider).errorMessage ??
          l10n.conversationListRenameFailed;
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.conversationListRenamedSnackBar)),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> deleteConversationFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  required bool compactSidebar,
  VoidCallback? onConversationSelected,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.clarityColors;
      return AlertDialog(
        title: Text(context.l10n.conversationListDeleteTitle),
        content: Text(context.l10n.conversationListDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.background,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  final wasCurrent = ref.read(chatProvider).conversationId == conversation.id;
  final deleted = await ref
      .read(conversationListProvider.notifier)
      .deleteConversation(conversation.id);

  if (!context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  if (!deleted) {
    final errorMessage =
        ref.read(conversationListProvider).errorMessage ??
        context.l10n.conversationListDeleteFailed;
    messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    return;
  }

  messenger.showSnackBar(
    SnackBar(content: Text(context.l10n.conversationListDeletedSnackBar)),
  );

  if (!wasCurrent) {
    return;
  }

  if (onConversationSelected != null || compactSidebar) {
    final next = await ref
        .read(conversationListProvider.notifier)
        .createConversation();
    if (!context.mounted) {
      return;
    }
    if (next != null) {
      ref.read(chatProvider.notifier).startConversation(next.id);
      onConversationSelected?.call();
    } else {
      ref.read(chatProvider.notifier).reset();
    }
  } else {
    Navigator.of(context).pop();
  }
}
