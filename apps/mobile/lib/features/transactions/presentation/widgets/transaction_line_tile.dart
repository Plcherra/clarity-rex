import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/models/models.dart';
import '../../../../theme/clarity_colors.dart';
import 'transaction_category_dropdown.dart';

/// One transaction row: date, description, category, amount.
///
/// Manual rows can be deleted here; Plaid rows cannot, because the next sync
/// would bring them back.
class TransactionLineTile extends StatelessWidget {
  const TransactionLineTile({
    required this.transaction,
    required this.displayCategory,
    required this.transactionController,
    this.horizontalPadding = 18,
    super.key,
  });

  final Transaction transaction;
  final String displayCategory;
  final TransactionUiController transactionController;

  /// Drops to zero inside a card that already indents its contents.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final tx = transaction;
    final muted = cs.onSurface.withValues(alpha: 0.42);
    final amountColor = tx.amount < 0
        ? ClarityColors.financeNegative
        : ClarityColors.financePositive;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              formatShortDate(tx.date),
              style: theme.textTheme.labelMedium?.copyWith(
                color: muted,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TransactionCategoryField(
                      controller: transactionController,
                      transaction: tx,
                      displayCategory: displayCategory,
                    ),
                    if (tx.pending) const _PendingChip(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(tx.amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
              if (!tx.isPlaid)
                IconButton(
                  tooltip: l10n.monthDetailDeleteTransactionTooltip,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: cs.error,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmAndDelete(context, tx),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, Transaction tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = ctx.l10n;
        return AlertDialog(
          title: Text(dialogL10n.monthDetailDeleteTransactionTitle),
          content: Text(dialogL10n.monthDetailDeleteTransactionBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dialogL10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(dialogL10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    final deleted = await transactionController.deleteTransaction(tx);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? context.l10n.monthDetailTransactionDeleted
              : context.l10n.monthDetailDeleteTransactionFailed,
        ),
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ClarityColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.transactionPendingChip,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: ClarityColors.warning,
        ),
      ),
    );
  }
}
