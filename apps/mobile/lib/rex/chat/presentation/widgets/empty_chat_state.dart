import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'empty_chat_prompts.dart';

class EmptyChatState extends StatelessWidget {
  const EmptyChatState({
    super.key,
    required this.welcomeMessage,
    required this.onPromptSelected,
    required this.hasLinkedAccounts,
  });

  final String welcomeMessage;
  final ValueChanged<String> onPromptSelected;
  final bool hasLinkedAccounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).height < 650;
    final prompts = emptyChatPrompts(
      l10n,
      hasLinkedAccounts: hasLinkedAccounts,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(2, compact ? 12 : 34, 2, 14),
      child: Padding(
        padding: EdgeInsets.all(compact ? RexUiTokens.space12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chatTranscriptReadyTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: RexUiTokens.space8),
              Text(
                welcomeMessage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: compact ? RexUiTokens.space12 : 18),
            Wrap(
              spacing: RexUiTokens.space8,
              runSpacing: RexUiTokens.space8,
              children: [
                for (var index = 0; index < prompts.length; index++)
                  ActionChip(
                    key: ValueKey('empty-chat-chip-$index'),
                    label: Text(prompts[index]),
                    onPressed: () => onPromptSelected(prompts[index]),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: colors.borderActive),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RexUiTokens.radiusPill,
                      ),
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
