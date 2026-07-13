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
            padding: ClarityNativeLayout.active(context)
                ? ClarityNativeLayout.pagePadding(
                    context,
                    top: 12,
                    bottom: 12,
                  )
                : const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
    final desktop = isClarityDesktopLayout(context);
    final native = ClarityNativeLayout.active(context);
    final cardPad = ClarityNativeLayout.cardPadding(context);
    final header = BudgetsHeader(
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
    );
    final summary = Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: desktop ? 520 : double.infinity),
        child: _BudgetSummaryStrip(metrics: metrics),
      ),
    );
    final chart = ClarityCard(
      padding: native
          ? cardPad
          : const EdgeInsets.fromLTRB(16, 12, 16, 14),
      borderRadius: native
          ? BorderRadius.circular(ClarityNativeLayout.cardRadius(context))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.budgetsScreenBudgetVsSpentTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          BudgetVsSpentChart(performance: metrics.performance),
        ],
      ),
    );
    final categories = BudgetCategoryList(
      items: data.categoryItems,
      controllers: controllers,
      focusNodes: focusNodes,
      onCategoryValueChanged: onDraftEdited,
      onTrackCategoryCount: metrics.performance.onTrackCategoryCount,
      budgetedCategoryCount: metrics.performance.budgetedCategoryCount,
    );

    if (desktop && !keyboardOpen) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: keyboardInset + 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 10),
                  summary,
                  const SizedBox(height: 10),
                  categories,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: chart),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: keyboardInset + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 10),
          summary,
          if (!keyboardOpen) ...[
            const SizedBox(height: 10),
            ClarityCard(
              padding: EdgeInsets.zero,
              borderRadius: native
                  ? BorderRadius.circular(
                      ClarityNativeLayout.cardRadius(context),
                    )
                  : null,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.08,
                  ),
                ),
                child: ExpansionTile(
                  // Native: one inset layer — page pad already applied; avoid +16.
                  tilePadding: native
                      ? EdgeInsets.fromLTRB(cardPad.left, 2, 8, 2)
                      : const EdgeInsets.fromLTRB(16, 2, 8, 2),
                  childrenPadding: native
                      ? EdgeInsets.fromLTRB(
                          cardPad.left,
                          0,
                          cardPad.right,
                          cardPad.bottom,
                        )
                      : const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
          categories,
        ],
      ),
    );
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
