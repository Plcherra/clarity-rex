import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';

class MemoryMetaChip extends StatelessWidget {
  const MemoryMetaChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: RexUiTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(RexUiTokens.radiusSmall),
        border: Border.all(color: RexUiTokens.border.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: RexUiTokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
