import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../data/financial_audit_service.dart';

/// Readable title for a financial audit event (shared by Activity + category sheet).
String financialAuditEventTitle(
  FinancialAuditEvent event,
  AppLocalizations l10n,
) {
  return switch (event.eventType) {
    'transaction_category_updated' =>
      l10n.categorySheetAuditTransactionCategoryChanged,
    'transaction_category_bulk_updated' =>
      l10n.categorySheetAuditBulkCategoryChange,
    'transaction_role_override_updated' =>
      l10n.categorySheetAuditTransactionRoleChanged,
    'category_deleted' => l10n.categorySheetAuditCategoryDeleted,
    'category_merged' => l10n.categorySheetAuditCategoryMerged,
    'category_visibility_updated' =>
      l10n.categorySheetAuditCategoryVisibilityChanged,
    'merchant_rule_category_updated' =>
      l10n.categorySheetAuditMerchantRuleChanged,
    'merchant_rule_disabled_updated' =>
      l10n.categorySheetAuditMerchantRuleEnabledDisabled,
    'merchant_rule_deleted' => l10n.categorySheetAuditMerchantRuleDeleted,
    'category_renamed' => l10n.categorySheetAuditCategoryRenamed,
    'category_created' => l10n.financialAuditCategoryCreated,
    'category_updated' => l10n.financialAuditCategoryUpdated,
    'budget_created' => l10n.financialAuditBudgetCreated,
    'budget_updated' => l10n.financialAuditBudgetUpdated,
    'budget_deleted' => l10n.financialAuditBudgetDeleted,
    'account_created' => l10n.financialAuditAccountCreated,
    'account_updated' => l10n.financialAuditAccountUpdated,
    'account_deleted' => l10n.financialAuditAccountDeleted,
    'transaction_created' => l10n.financialAuditTransactionCreated,
    'transaction_updated' => l10n.financialAuditTransactionUpdated,
    'transaction_deleted' => l10n.financialAuditTransactionDeleted,
    'import_batch_deleted' => l10n.financialAuditImportBatchDeleted,
    _ => event.eventType.replaceAll('_', ' '),
  };
}

/// Subtitle: value delta · optional count · source · timestamp.
String financialAuditEventSubtitle(
  FinancialAuditEvent event,
  AppLocalizations l10n,
) {
  final oldLabel = financialAuditValueLabel(event.previousValue, l10n);
  final newLabel = financialAuditValueLabel(event.newValue, l10n);
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
    parts.add(l10n.commonTransactionCount(count.toInt()));
  }
  parts.add(event.source);
  parts.add(financialAuditDateTimeLabel(event.createdAt.toLocal()));
  return parts.join(' · ');
}

String? financialAuditValueLabel(
  Map<String, dynamic> value,
  AppLocalizations l10n,
) {
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
  if (hidden is bool) return hidden ? l10n.commonHidden : l10n.commonVisible;
  return null;
}

String financialAuditDateTimeLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}

final class FinancialAuditEventRow extends StatelessWidget {
  const FinancialAuditEventRow({super.key, required this.event});

  final FinancialAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
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
                  financialAuditEventTitle(event, l10n),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  financialAuditEventSubtitle(event, l10n),
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
