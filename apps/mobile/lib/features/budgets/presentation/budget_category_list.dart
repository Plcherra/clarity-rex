import 'package:flutter/material.dart';

import '../../../core/layout/clarity_native_layout.dart';
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
    final native = ClarityNativeLayout.active(context);
    final cardPad = ClarityNativeLayout.cardPadding(context);

    return ClarityCard(
      padding: EdgeInsets.zero,
      borderRadius: native
          ? BorderRadius.circular(ClarityNativeLayout.cardRadius(context))
          : null,
      backgroundColor: cs.surface,
      borderColor: cs.outline.withValues(alpha: 0.24),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: cs.primary.withValues(alpha: 0.08),
        ),
        child: ExpansionTile(
          tilePadding: native
              ? EdgeInsets.fromLTRB(cardPad.left, 2, 8, 2)
              : const EdgeInsets.fromLTRB(16, 2, 8, 2),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: true,
          iconColor: cs.onSurface.withValues(alpha: 0.56),
          collapsedIconColor: cs.onSurface.withValues(alpha: 0.56),
          title: Text(
            l10n.budgetCategoryListTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            l10n.commonOnTrack(onTrackCategoryCount, budgetedCategoryCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.56),
            ),
          ),
          children: [
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
            if (items.isEmpty)
              Padding(
                padding: native
                    ? EdgeInsets.fromLTRB(
                        cardPad.left,
                        16,
                        cardPad.right,
                        16,
                      )
                    : const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Text(
                  l10n.budgetCategoryListEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              )
            else
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    color: cs.outline.withValues(alpha: 0.06),
                  ),
                _BudgetCategoryListRow(
                  item: items[index],
                  controller: controllers[items[index].canonical],
                  focusNode: focusNodes[items[index].canonical],
                  onCategoryValueChanged: onCategoryValueChanged,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _BudgetCategoryListRow extends StatelessWidget {
  const _BudgetCategoryListRow({
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.onCategoryValueChanged,
  });

  final BudgetCategoryListItemData item;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onCategoryValueChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      controller: controller!,
      focusNode: focusNode!,
      indicatorColor: indicatorColor,
      statusText: item.statusText,
      statusColor: statusColor,
      onValueChanged: onCategoryValueChanged,
    );
  }
}
