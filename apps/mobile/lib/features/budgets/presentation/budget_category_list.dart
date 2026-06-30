import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';
import '../../../widgets/clarity_card.dart';
import 'budget_category_row.dart';
import 'budgets_viewmodel.dart';

class BudgetCategoryList extends StatelessWidget {
  const BudgetCategoryList({
    super.key,
    required this.items,
    required this.controllers,
    required this.focusNodes,
    required this.onTrackCategoryCount,
    required this.budgetedCategoryCount,
    required this.onCategoryValueChanged,
  });

  final List<BudgetCategoryListItemData> items;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final int onTrackCategoryCount;
  final int budgetedCategoryCount;
  final ValueChanged<String> onCategoryValueChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return ClarityCard(
      padding: EdgeInsets.zero,
      backgroundColor: cs.surface,
      borderColor: cs.outline.withValues(alpha: 0.24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Text(
                  l10n.budgetCategoryListTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    letterSpacing: 0.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.commonOnTrack(onTrackCategoryCount, budgetedCategoryCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      l10n.budgetCategoryListEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.56),
                      ),
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      4,
                      4,
                      4,
                      4 + keyboardInset,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: cs.outline.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final controller = controllers[item.canonical];
                      final focusNode = focusNodes[item.canonical];
                      if (controller == null || focusNode == null) {
                        return const SizedBox.shrink();
                      }
                      final indicatorColor = !item.hasBudget
                          ? cs.onSurface.withValues(alpha: 0.32)
                          : item.isOverspent
                          ? ClarityColors.financeNegative
                          : ClarityColors.financePositive;
                      final statusColor = item.isOverspent
                          ? ClarityColors.financeNegative
                          : cs.onSurface.withValues(alpha: 0.58);
                      return BudgetCategoryRowTile(
                        displayLabel: item.displayLabel,
                        controller: controller,
                        focusNode: focusNode,
                        indicatorColor: indicatorColor,
                        statusText: item.statusText,
                        statusColor: statusColor,
                        onValueChanged: onCategoryValueChanged,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
