import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/models/models.dart';
import '../../../../theme/clarity_colors.dart';
import 'source_label_chip.dart';

class ManualAccountTile extends StatelessWidget {
  const ManualAccountTile({super.key, required this.item, required this.onTap});

  final AccountOverviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final account = item.account;
    final inst = account.institution?.trim();
    final subtitle = [
      account.type.displayLabel,
      if (inst != null && inst.isNotEmpty) inst,
    ].join(' / ');
    final balance = item.displayBalanceAmount;
    final hasMonthlyActivity =
        item.incomeThisMonth != 0 ||
        item.spentThisMonth != 0 ||
        item.netCashFlow != 0;
    final l10n = context.l10n;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: cs.surfaceContainerHighest,
                foregroundColor: cs.onSurface.withValues(alpha: 0.78),
                child: Icon(_accountIcon(account.type), size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SourceLabelChip(label: account.sourceLabel),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.56),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.balanceLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    balance == null ? l10n.commonUnavailable : formatMoney(balance),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: balance == null
                          ? cs.onSurface.withValues(alpha: 0.46)
                          : cs.onSurface,
                    ),
                  ),
                  if (hasMonthlyActivity) ...[
                    const SizedBox(height: 3),
                    Text(
                      l10n.accountTileThisMonthNet(formatMoney(item.netCashFlow)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: item.netCashFlow > 0
                            ? ClarityColors.financePositive
                            : item.netCashFlow < 0
                            ? ClarityColors.financeNegative
                            : cs.onSurface.withValues(alpha: 0.46),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.accountTileViewAccount,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.46),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurface.withValues(alpha: 0.34),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _accountIcon(AccountType type) {
    return switch (type) {
      AccountType.checking => Icons.account_balance_outlined,
      AccountType.savings => Icons.savings_outlined,
      AccountType.creditCard => Icons.credit_card_rounded,
    };
  }
}
