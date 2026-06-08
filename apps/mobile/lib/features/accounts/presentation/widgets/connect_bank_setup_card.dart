import 'package:flutter/material.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outline.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: compact ? 34 : 42,
              color: cs.onSurface.withValues(alpha: 0.78),
            ),
            SizedBox(height: compact ? 16 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.62),
                height: 1.35,
              ),
            ),
            SizedBox(height: compact ? 18 : 24),
            FilledButton.icon(
              onPressed: onConnectBank,
              icon: const Icon(Icons.add_link_rounded, size: 20),
              label: const Text('Connect Bank'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onImportCsvInstead,
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              label: const Text('Import CSV instead'),
            ),
            if (onAddManualAccount != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAddManualAccount,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add manual account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
