part of 'budgets_screen.dart';

class _BudgetsScaffold extends StatelessWidget {
  const _BudgetsScaffold({
    required this.viewModel,
    required this.dataNotifier,
    required this.selectedType,
    required this.selectedPeriodKey,
    required this.keys,
    required this.weeklyDate,
    required this.customStart,
    required this.customEnd,
    required this.compactButtonStyle,
    required this.canAttemptSave,
    required this.controllers,
    required this.focusNodes,
    required this.onManageCategories,
    required this.onSave,
    required this.onPeriodTypeChanged,
    required this.onPickMonthly,
    required this.onPickWeekly,
    required this.onPickCustomStart,
    required this.onPickCustomEnd,
    required this.onDraftEdited,
  });

  final BudgetsViewModel viewModel;
  final _BudgetsDataNotifier dataNotifier;
  final BudgetPeriodType selectedType;
  final String selectedPeriodKey;
  final List<String> keys;
  final DateTime? weeklyDate;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ButtonStyle compactButtonStyle;
  final bool canAttemptSave;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final VoidCallback onManageCategories;
  final Future<bool> Function(List<BudgetCategoryRow> rows) onSave;
  final Future<void> Function(BudgetPeriodType type) onPeriodTypeChanged;
  final Future<void> Function() onPickMonthly;
  final Future<void> Function() onPickWeekly;
  final Future<void> Function() onPickCustomStart;
  final Future<void> Function() onPickCustomEnd;
  final ValueChanged<String> onDraftEdited;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final rows = dataNotifier.data?.rows ?? const <BudgetCategoryRow>[];
    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 6,
        title: Text(l10n.navBudgets),
        leading: const SizedBox(width: 48),
        actions: [
          IconButton(
            tooltip: l10n.budgetsScreenManageCategoriesTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onManageCategories,
            icon: const Icon(Icons.category_outlined, size: 22),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: viewModel.hasUnsavedChanges,
            builder: (context, hasChanges, _) {
              final canSave = canAttemptSave && hasChanges;
              return IconButton(
                tooltip: l10n.budgetsScreenSaveChangesTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: canSave
                    ? () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await onSave(rows);
                      }
                    : null,
                icon: Icon(
                  Icons.check_rounded,
                  size: 22,
                  color: hasChanges
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.34),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: ListenableBuilder(
              listenable: dataNotifier,
              builder: (context, _) {
                final data = dataNotifier.data;
                if (data == null) {
                  if (dataNotifier.error != null) {
                    return Center(child: Text(l10n.budgetsScreenLoadError));
                  }
                  return Center(
                    child: ClarityDiamondLoader(
                      size: 56,
                      label: l10n.budgetsScreenLoadingLabel,
                    ),
                  );
                }
                return _BudgetsLoadedContent(
                  viewModel: viewModel,
                  selectedType: selectedType,
                  selectedPeriodKey: selectedPeriodKey,
                  keys: keys,
                  weeklyDate: weeklyDate,
                  customStart: customStart,
                  customEnd: customEnd,
                  compactButtonStyle: compactButtonStyle,
                  data: data,
                  controllers: controllers,
                  focusNodes: focusNodes,
                  onPeriodTypeChanged: onPeriodTypeChanged,
                  onPickMonthly: onPickMonthly,
                  onPickWeekly: onPickWeekly,
                  onPickCustomStart: onPickCustomStart,
                  onPickCustomEnd: onPickCustomEnd,
                  onDraftEdited: onDraftEdited,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetsLoadedContent extends StatelessWidget {
  const _BudgetsLoadedContent({
    required this.viewModel,
    required this.selectedType,
    required this.selectedPeriodKey,
    required this.keys,
    required this.weeklyDate,
    required this.customStart,
    required this.customEnd,
    required this.compactButtonStyle,
    required this.data,
    required this.controllers,
    required this.focusNodes,
    required this.onPeriodTypeChanged,
    required this.onPickMonthly,
    required this.onPickWeekly,
    required this.onPickCustomStart,
    required this.onPickCustomEnd,
    required this.onDraftEdited,
  });

  final BudgetsViewModel viewModel;
  final BudgetPeriodType selectedType;
  final String selectedPeriodKey;
  final List<String> keys;
  final DateTime? weeklyDate;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ButtonStyle compactButtonStyle;
  final _BudgetScreenData data;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final Future<void> Function(BudgetPeriodType type) onPeriodTypeChanged;
  final Future<void> Function() onPickMonthly;
  final Future<void> Function() onPickWeekly;
  final Future<void> Function() onPickCustomStart;
  final Future<void> Function() onPickCustomEnd;
  final ValueChanged<String> onDraftEdited;

  @override
  Widget build(BuildContext context) {
    final metrics = data.metrics;
    final l10n = context.l10n;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: keyboardInset + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BudgetsHeader(
            selectedType: selectedType,
            selectedPeriodKey: selectedPeriodKey,
            keys: keys,
            monthlyLabel: selectedPeriodKey.trim().isEmpty
                ? l10n.budgetsHeaderSelectMonth
                : formatYearMonthLabel(selectedPeriodKey),
            weeklyLabel: weeklyDate == null
                ? l10n.budgetsHeaderPickWeekStart
                : viewModel.formatLongDate(weeklyDate!),
            weeklyRangeLabel: viewModel.weeklyRangeLabel(selectedPeriodKey),
            customStartLabel: customStart == null
                ? l10n.commonStart
                : formatShortDate(customStart!),
            customEndLabel: customEnd == null
                ? l10n.commonEnd
                : formatShortDate(customEnd!),
            onPeriodTypeChanged: onPeriodTypeChanged,
            onPickMonthly: onPickMonthly,
            onPickWeekly: onPickWeekly,
            onPickCustomStart: onPickCustomStart,
            onPickCustomEnd: onPickCustomEnd,
            compactButtonStyle: compactButtonStyle,
          ),
          const SizedBox(height: 10),
          _BudgetSummaryStrip(metrics: metrics),
          if (!keyboardOpen) ...[
            const SizedBox(height: 10),
            ClarityCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.08,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  initiallyExpanded: false,
                  iconColor: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.56,
                  ),
                  collapsedIconColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.56),
                  title: Text(
                    l10n.budgetsScreenBudgetVsSpentTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    BudgetVsSpentChart(performance: metrics.performance),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          BudgetCategoryList(
            items: data.categoryItems,
            controllers: controllers,
            focusNodes: focusNodes,
            onCategoryValueChanged: onDraftEdited,
            onTrackCategoryCount: metrics.performance.onTrackCategoryCount,
            budgetedCategoryCount: metrics.performance.budgetedCategoryCount,
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryStrip extends StatelessWidget {
  const _BudgetSummaryStrip({required this.metrics});

  final BudgetsPresentationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ClarityCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.24),
      borderColor: cs.outline.withValues(alpha: 0.18),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: l10n.commonBudgeted,
              value: formatMoney(metrics.performance.totalBudgeted),
              valueColor: cs.onSurface,
              alignment: CrossAxisAlignment.start,
            ),
          ),
          _SummaryDivider(color: cs.outline.withValues(alpha: 0.10)),
          Expanded(
            child: _SummaryMetric(
              label: l10n.commonSpent,
              value: formatMoney(metrics.performance.totalSpent),
              valueColor: cs.onSurface,
              alignment: CrossAxisAlignment.center,
            ),
          ),
          _SummaryDivider(color: cs.outline.withValues(alpha: 0.10)),
          Expanded(
            child: _SummaryMetric(
              label: metrics.totalOver > 0 ? l10n.commonOver : l10n.commonLeft,
              value: metrics.totalOver > 0
                  ? formatMoney(metrics.totalOver)
                  : formatMoney(metrics.totalRemaining),
              valueColor: metrics.totalOver > 0
                  ? ClarityColors.financeNegative
                  : ClarityColors.financePositive,
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: color);
  }
}

class _BudgetsDataNotifier extends ChangeNotifier {
  _BudgetScreenData? _data;
  Object? _error;
  var _loading = false;

  _BudgetScreenData? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  void setLoading() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void setData(_BudgetScreenData data) {
    _data = data;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void setError(Object error) {
    _error = error;
    _loading = false;
    notifyListeners();
  }
}

class _BudgetScreenData {
  const _BudgetScreenData({
    required this.rows,
    required this.metrics,
    required this.categoryItems,
  });

  final List<BudgetCategoryRow> rows;
  final BudgetsPresentationMetrics metrics;
  final List<BudgetCategoryListItemData> categoryItems;
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.alignment,
  });

  final String label;
  final String value;
  final Color valueColor;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.54),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
