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
    final rows = dataNotifier.data?.rows ?? const <BudgetCategoryRow>[];
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 6,
        title: const Text('Budgets'),
        leading: const SizedBox(width: 48),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            visualDensity: VisualDensity.compact,
            onPressed: onManageCategories,
            icon: const Icon(Icons.category_outlined, size: 22),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: viewModel.hasUnsavedChanges,
            builder: (context, hasChanges, _) {
              final canSave = canAttemptSave && hasChanges;
              return IconButton(
                tooltip: 'Save changes',
                visualDensity: VisualDensity.compact,
                onPressed: canSave ? () async => onSave(rows) : null,
                icon: Icon(
                  Icons.check_rounded,
                  size: 22,
                  color: hasChanges ? cs.primary : Colors.grey,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: ListenableBuilder(
            listenable: dataNotifier,
            builder: (context, _) {
              final data = dataNotifier.data;
              if (data == null) {
                if (dataNotifier.error != null) {
                  return const Center(child: Text('Could not load budgets.'));
                }
                return const Center(child: CircularProgressIndicator());
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BudgetsHeader(
          selectedType: selectedType,
          selectedPeriodKey: selectedPeriodKey,
          keys: keys,
          monthlyLabel: selectedPeriodKey.trim().isEmpty
              ? 'Select month'
              : formatYearMonthLabel(selectedPeriodKey),
          weeklyLabel: weeklyDate == null
              ? 'Pick week start'
              : viewModel.formatLongDate(weeklyDate!),
          weeklyRangeLabel: viewModel.weeklyRangeLabel(selectedPeriodKey),
          customStartLabel: customStart == null
              ? 'Start'
              : formatShortDate(customStart!),
          customEndLabel: customEnd == null
              ? 'End'
              : formatShortDate(customEnd!),
          onPeriodTypeChanged: onPeriodTypeChanged,
          onPickMonthly: onPickMonthly,
          onPickWeekly: onPickWeekly,
          onPickCustomStart: onPickCustomStart,
          onPickCustomEnd: onPickCustomEnd,
          compactButtonStyle: compactButtonStyle,
        ),
        const SizedBox(height: 14),
        _BudgetSummaryStrip(metrics: metrics),
        const SizedBox(height: 14),
        Expanded(
          child: BudgetCategoryList(
            items: data.categoryItems,
            controllers: controllers,
            focusNodes: focusNodes,
            onCategoryValueChanged: onDraftEdited,
            onTrackCategoryCount: metrics.performance.onTrackCategoryCount,
            budgetedCategoryCount: metrics.performance.budgetedCategoryCount,
          ),
        ),
      ],
    );
  }
}

class _BudgetSummaryStrip extends StatelessWidget {
  const _BudgetSummaryStrip({required this.metrics});

  final BudgetsPresentationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'Budgeted',
              value: formatMoney(metrics.performance.totalBudgeted),
              valueColor: cs.onSurface,
              alignment: CrossAxisAlignment.start,
            ),
          ),
          _SummaryDivider(color: cs.outline.withValues(alpha: 0.10)),
          Expanded(
            child: _SummaryMetric(
              label: 'Spent',
              value: formatMoney(metrics.performance.totalSpent),
              valueColor: cs.onSurface,
              alignment: CrossAxisAlignment.center,
            ),
          ),
          _SummaryDivider(color: cs.outline.withValues(alpha: 0.10)),
          Expanded(
            child: _SummaryMetric(
              label: metrics.totalOver > 0 ? 'Over' : 'Left',
              value: metrics.totalOver > 0
                  ? formatMoney(metrics.totalOver)
                  : formatMoney(metrics.totalRemaining),
              valueColor: metrics.totalOver > 0
                  ? const Color(0xFFC41E3A)
                  : const Color(0xFF1B7A4C),
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
