part of 'category_management_sheet.dart';

enum _CategoryManagementSection { categories, merchantRules, auditTrail }

class _CategoryManagementRow extends StatelessWidget {
  const _CategoryManagementRow({
    required this.category,
    required this.usage,
    required this.custom,
    required this.saving,
    required this.onRename,
    required this.onDelete,
    required this.onMerge,
    required this.onToggleHidden,
  });

  final CategoryRecord category;
  final _CategoryUsageStats usage;
  final bool custom;
  final bool saving;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onMerge;
  final VoidCallback? onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final usageLabel = usage.label(l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (usageLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    usageLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!custom)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                l10n.commonBuiltIn,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (custom && category.hidden)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                l10n.commonHidden,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          PopupMenuButton<_CategoryRowAction>(
            tooltip: l10n.categorySheetCategoryActionsTooltip,
            enabled: !saving && custom,
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) {
              switch (action) {
                case _CategoryRowAction.toggleHidden:
                  onToggleHidden?.call();
                  break;
                case _CategoryRowAction.merge:
                  onMerge?.call();
                  break;
                case _CategoryRowAction.rename:
                  onRename?.call();
                  break;
                case _CategoryRowAction.delete:
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _CategoryRowAction.toggleHidden,
                child: ListTile(
                  leading: Icon(
                    category.hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  title: Text(
                    category.hidden
                        ? l10n.categorySheetShowInPickers
                        : l10n.categorySheetHideFromPickers,
                  ),
                ),
              ),
              PopupMenuItem(
                value: _CategoryRowAction.merge,
                child: ListTile(
                  leading: const Icon(Icons.merge_type_rounded),
                  title: Text(l10n.commonMerge),
                ),
              ),
              PopupMenuItem(
                value: _CategoryRowAction.rename,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.commonRename),
                ),
              ),
              PopupMenuItem(
                value: _CategoryRowAction.delete,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(l10n.commonDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _CategoryRowAction { toggleHidden, merge, rename, delete }

class _MerchantRuleManagementRow extends StatelessWidget {
  const _MerchantRuleManagementRow({
    required this.rule,
    required this.category,
    required this.stats,
    required this.saving,
    required this.onEditCategory,
    required this.onToggleDisabled,
    required this.onDelete,
  });

  final MerchantCategoryRule rule;
  final CategoryRecord? category;
  final _MerchantRuleStats stats;
  final bool saving;
  final VoidCallback onEditCategory;
  final VoidCallback onToggleDisabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final merchantDisplay = rule.merchantDisplay?.trim();
    final title = merchantDisplay != null && merchantDisplay.isNotEmpty
        ? merchantDisplay
        : rule.merchantKey;
    final categoryName = category?.name ?? l10n.categorySheetMissingCategory;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        color: rule.disabled
            ? cs.errorContainer.withValues(alpha: 0.16)
            : cs.surfaceContainerHighest.withValues(alpha: 0.22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: category == null
                        ? cs.error
                        : cs.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stats.label(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (rule.disabled)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                l10n.commonDisabled,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          PopupMenuButton<_MerchantRuleAction>(
            tooltip: l10n.categorySheetMerchantRuleActionsTooltip,
            enabled: !saving,
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) {
              switch (action) {
                case _MerchantRuleAction.editCategory:
                  onEditCategory();
                  break;
                case _MerchantRuleAction.toggleDisabled:
                  onToggleDisabled();
                  break;
                case _MerchantRuleAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MerchantRuleAction.editCategory,
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l10n.categorySheetChangeCategory),
                ),
              ),
              PopupMenuItem(
                value: _MerchantRuleAction.toggleDisabled,
                child: ListTile(
                  leading: Icon(
                    rule.disabled
                        ? Icons.play_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                  ),
                  title: Text(
                    rule.disabled
                        ? l10n.categorySheetEnableRule
                        : l10n.categorySheetDisableRule,
                  ),
                ),
              ),
              PopupMenuItem(
                value: _MerchantRuleAction.delete,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(l10n.categorySheetDeleteRule),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MerchantRuleAction { editCategory, toggleDisabled, delete }

class _MerchantRuleStats {
  const _MerchantRuleStats({
    this.transactionCount = 0,
    this.latestTransactionDate,
  });

  final int transactionCount;
  final DateTime? latestTransactionDate;

  String label(AppLocalizations l10n) {
    final latest = latestTransactionDate;
    if (latest == null) {
      return l10n.merchantRuleStatsMatchingTx(transactionCount);
    }
    return l10n.merchantRuleStatsMatchingTxLastUsed(
      transactionCount,
      _dateLabel(latest),
    );
  }

  static String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _CategoryUsageStats {
  const _CategoryUsageStats({
    this.transactionCount = 0,
    this.budgetCount = 0,
    this.merchantRuleCount = 0,
  });

  final int transactionCount;
  final int budgetCount;
  final int merchantRuleCount;

  String label(AppLocalizations l10n) {
    final parts = <String>[
      if (transactionCount > 0) l10n.categoryUsageTxCount(transactionCount),
      if (budgetCount > 0) l10n.categoryUsageBudgetCount(budgetCount),
      if (merchantRuleCount > 0) l10n.categoryUsageRuleCount(merchantRuleCount),
    ];
    return parts.join(' · ');
  }

  bool get hasAny =>
      transactionCount > 0 || budgetCount > 0 || merchantRuleCount > 0;
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.52),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
