import 'package:flutter/material.dart';

import '../../../../core/formatting/formatting.dart';
import '../../../../core/models/models.dart';
import 'source_label_chip.dart';

class PlaidRecentTransactions extends StatelessWidget {
  const PlaidRecentTransactions({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          'No synced transactions yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.52),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent transactions',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final transaction in transactions) ...[
            _PlaidTransactionRow(transaction: transaction),
            if (!identical(transaction, transactions.last))
              Divider(height: 14, color: cs.onSurface.withValues(alpha: 0.08)),
          ],
        ],
      ),
    );
  }
}

class _PlaidTransactionRow extends StatelessWidget {
  const _PlaidTransactionRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final description = transaction.description.trim().isEmpty
        ? 'Transaction'
        : transaction.description.trim();
    final amount = transaction.amount;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 7,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SourceLabelChip(label: transaction.sourceLabel),
                  if (transaction.pending)
                    const SourceLabelChip(label: 'Pending'),
                  Text(
                    _shortDate(transaction.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMoney(amount),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: amount > 0
                ? const Color(0xFF1B7A4C)
                : amount < 0
                ? const Color(0xFFC41E3A)
                : cs.onSurface,
          ),
        ),
      ],
    );
  }

  String _shortDate(DateTime value) {
    return '${value.month}/${value.day}/${value.year}';
  }
}
