import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/models/models.dart';
import '../../../../theme/clarity_colors.dart';
import 'transaction_category_dropdown.dart';

/// One transaction row: date, description, category and role pickers, amount.
///
/// Manual rows can be deleted here; Plaid rows cannot, because the next sync
/// would bring them back.
class TransactionLineTile extends StatelessWidget {
  const TransactionLineTile({
    required this.transaction,
    required this.displayCategory,
    required this.transactionController,
    super.key,
  });

  final Transaction transaction;
  final String displayCategory;
  final TransactionUiController transactionController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tx = transaction;
    final muted = cs.onSurface.withValues(alpha: 0.42);
    final amountColor = tx.amount < 0
        ? ClarityColors.financeNegative
        : ClarityColors.financePositive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                TransactionCategoryField(
                  controller: transactionController,
                  transaction: tx,
                  displayCategory: displayCategory,
                ),
                const SizedBox(height: 6),
                TransactionRoleField(
                  controller: transactionController,
                  transaction: tx,
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
                  tooltip: context.l10n.monthDetailDeleteTransactionTooltip,
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
