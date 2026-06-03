part of 'category_management_sheet.dart';

enum _CategoryManagementSection { categories, merchantRules, auditTrail }

class _AuditEventRow extends StatelessWidget {
  const _AuditEventRow({required this.event});

  final FinancialAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _auditEventTitle(event),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _auditEventSubtitle(event),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
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
                const SizedBox(height: 3),
                Text(
                  usage.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!custom)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'Built-in',
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
                'Hidden',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          PopupMenuButton<_CategoryRowAction>(
            tooltip: 'Category actions',
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
                    category.hidden ? 'Show in pickers' : 'Hide from pickers',
                  ),
                ),
              ),
              const PopupMenuItem(
                value: _CategoryRowAction.merge,
                child: ListTile(
                  leading: Icon(Icons.merge_type_rounded),
                  title: Text('Merge'),
                ),
              ),
              const PopupMenuItem(
                value: _CategoryRowAction.rename,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Rename'),
                ),
              ),
              const PopupMenuItem(
                value: _CategoryRowAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete'),
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
    final merchantDisplay = rule.merchantDisplay?.trim();
    final title = merchantDisplay != null && merchantDisplay.isNotEmpty
        ? merchantDisplay
        : rule.merchantKey;
    final categoryName = category?.name ?? 'Missing category';
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
                  stats.label,
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
                'Disabled',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          PopupMenuButton<_MerchantRuleAction>(
            tooltip: 'Merchant rule actions',
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
              const PopupMenuItem(
                value: _MerchantRuleAction.editCategory,
                child: ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Change category'),
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
                  title: Text(rule.disabled ? 'Enable rule' : 'Disable rule'),
                ),
              ),
              const PopupMenuItem(
                value: _MerchantRuleAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete rule'),
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

String _auditEventTitle(FinancialAuditEvent event) {
  return switch (event.eventType) {
    'transaction_category_updated' => 'Transaction category changed',
    'transaction_category_bulk_updated' => 'Bulk category change',
    'transaction_role_override_updated' => 'Transaction role changed',
    'category_deleted' => 'Category deleted',
    'category_merged' => 'Category merged',
    'category_visibility_updated' => 'Category visibility changed',
    'merchant_rule_category_updated' => 'Merchant rule changed',
    'merchant_rule_disabled_updated' => 'Merchant rule enabled/disabled',
    'merchant_rule_deleted' => 'Merchant rule deleted',
    'category_renamed' => 'Category renamed',
    _ => event.eventType.replaceAll('_', ' '),
  };
}

String _auditEventSubtitle(FinancialAuditEvent event) {
  final oldLabel = _auditLabel(event.previousValue);
  final newLabel = _auditLabel(event.newValue);
  final parts = <String>[];
  if (oldLabel != null && newLabel != null && oldLabel != newLabel) {
    parts.add('$oldLabel -> $newLabel');
  } else if (newLabel != null) {
    parts.add(newLabel);
  } else if (oldLabel != null) {
    parts.add(oldLabel);
  }
  final count = event.metadata['transaction_count'];
  if (count is num && count > 1) {
    parts.add('${count.toInt()} transactions');
  }
  parts.add(event.source);
  parts.add(_dateTimeLabel(event.createdAt.toLocal()));
  return parts.join(' · ');
}

String? _auditLabel(Map<String, dynamic> value) {
  for (final key in [
    'category_name',
    'name',
    'merchant_display',
    'merchant_key',
    'financial_role',
    'category_id',
  ]) {
    final raw = value[key];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  }
  final hidden = value['hidden'];
  if (hidden is bool) return hidden ? 'Hidden' : 'Visible';
  return null;
}

String _dateTimeLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}

class _MerchantRuleStats {
  const _MerchantRuleStats({
    this.transactionCount = 0,
    this.latestTransactionDate,
  });

  final int transactionCount;
  final DateTime? latestTransactionDate;

  String get label {
    final latest = latestTransactionDate;
    if (latest == null) return '$transactionCount matching tx';
    return '$transactionCount matching tx · last used ${_dateLabel(latest)}';
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

  String get label {
    return '$transactionCount tx · $budgetCount budgets · '
        '$merchantRuleCount rules';
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
