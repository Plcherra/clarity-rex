import 'package:flutter/material.dart';

import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';
import '../../transactions/domain/merchant_rollup.dart';
import '../../transactions/domain/transaction_resolution.dart';
import '../domain/category_month_detail.dart';
import 'category_detail_panel.dart';

/// Who took the money inside the category — the split a single label hides.
///
/// The rows stay folded behind the place that charged them. A month of coffee
/// is three lines here instead of forty rows the user has to read to find out
/// that most of "Coffee / Quick Food" was actually one wing shop.
class CategoryDetailMerchants extends StatefulWidget {
  const CategoryDetailMerchants({
    required this.detail,
    required this.buildTransactionRow,
    super.key,
  });

  final CategoryMonthDetail detail;

  /// How one transaction is drawn once its merchant is opened.
  final Widget Function(ResolvedTransaction row) buildTransactionRow;

  @override
  State<CategoryDetailMerchants> createState() =>
      _CategoryDetailMerchantsState();
}

class _CategoryDetailMerchantsState extends State<CategoryDetailMerchants> {
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final merchants = widget.detail.merchants;
    if (merchants.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final biggest = merchants.first.spent;

    return CategoryDetailPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categoryDetailWhereItWent,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.categoryDetailTapMerchantHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          for (final merchant in merchants)
            _MerchantRow(
              merchant: merchant,
              share: biggest <= 0 ? 0 : merchant.spent / biggest,
              expanded: _expanded.contains(merchant.merchant),
              onTap: () => setState(() {
                if (!_expanded.remove(merchant.merchant)) {
                  _expanded.add(merchant.merchant);
                }
              }),
              buildTransactionRow: widget.buildTransactionRow,
            ),
        ],
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.merchant,
    required this.share,
    required this.expanded,
    required this.onTap,
    required this.buildTransactionRow,
  });

  final MerchantSpendRollup merchant;
  final double share;
  final bool expanded;
  final VoidCallback onTap;
  final Widget Function(ResolvedTransaction row) buildTransactionRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        merchant.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      merchant.transactionCount == 1
                          ? l10n.commonTransactionCountOne
                          : l10n.commonTransactionCount(
                              merchant.transactionCount,
                            ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatMoney(merchant.spent),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: share,
                    backgroundColor: context.clarityColors.surfaceElevated,
                    color: ClarityColors.financeSpending,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                for (final row in merchant.transactions)
                  buildTransactionRow(row),
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
