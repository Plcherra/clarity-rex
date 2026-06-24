import 'package:flutter/material.dart';

import '../../../../theme/clarity_colors.dart';
import '../../../../widgets/clarity_card.dart';

class AccountNoticeCard extends StatelessWidget {
  const AccountNoticeCard({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const success = ClarityColors.financePositive;
    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      backgroundColor: success.withValues(alpha: 0.16),
      borderColor: success.withValues(alpha: 0.42),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
