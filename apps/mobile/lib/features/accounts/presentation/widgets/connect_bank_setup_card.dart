import 'package:flutter/material.dart';

import '../../../../widgets/clarity_button.dart';
import '../../../../widgets/clarity_card.dart';

class ConnectBankSetupCard extends StatelessWidget {
  const ConnectBankSetupCard({
    super.key,
    required this.title,
    required this.body,
    required this.onConnectBank,
    required this.onImportCsvInstead,
    this.onAddManualAccount,
    this.compact = false,
  });

  final String title;
  final String body;
  final VoidCallback onConnectBank;
  final VoidCallback onImportCsvInstead;
  final VoidCallback? onAddManualAccount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ClarityCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.account_balance_rounded,
            size: compact ? 28 : 32,
            color: cs.onSurface.withValues(alpha: 0.78),
          ),
          SizedBox(height: compact ? 12 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.62),
              height: 1.3,
              fontSize: 14,
            ),
          ),
          SizedBox(height: compact ? 14 : 16),
          ClarityButton.filled(
            label: 'Connect Bank',
            onPressed: onConnectBank,
            icon: const Icon(Icons.add_link_rounded, size: 18),
            expanded: true,
          ),
          const SizedBox(height: 8),
          ClarityButton.text(
            label: 'Import CSV instead',
            onPressed: onImportCsvInstead,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            expanded: true,
          ),
          if (onAddManualAccount != null) ...[
            const SizedBox(height: 4),
            ClarityButton.text(
              label: 'Add manual account',
              onPressed: onAddManualAccount,
              icon: const Icon(Icons.add_rounded, size: 17),
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }
}
