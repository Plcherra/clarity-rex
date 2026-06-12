import 'package:flutter/material.dart';

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
    const success = Color(0xFF1B7A4C);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: success.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
      ),
    );
  }
}
