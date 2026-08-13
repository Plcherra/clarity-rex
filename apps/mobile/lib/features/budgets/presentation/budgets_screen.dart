import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/budget_models.dart';
import '../../../core/layout/clarity_adaptive_overlay.dart';
import '../../../core/layout/clarity_breakpoints.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../theme/clarity_colors.dart';
import '../../../widgets/clarity_card.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import 'budget_category_list.dart';
import 'budgets_header.dart';
import 'budgets_viewmodel.dart';
import 'category_management_sheet.dart';
import '../../dashboard/presentation/charts/finance_charts.dart';
import 'budgets_category_detail.dart';

part 'budgets_screen_widgets.dart';
part 'budgets_screen_summary.dart';

/// Monthly budgets per category (picker list). Hidden categories are omitted here;
/// their persisted amounts remain until edited elsewhere (Rule A).
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({
    super.key,
    required this.controller,
    required this.dashboardController,
    required this.transactionController,
    this.manageCategoriesRequest = 0,
  });

  final BudgetUiController controller;
  final DashboardUiController dashboardController;
  final TransactionUiController transactionController;
  final int manageCategoriesRequest;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

enum _PeriodSwitchChoice { save, discard, cancel }

class _BudgetsScreenState extends State<BudgetsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  late final BudgetsViewModel _viewModel;
  late final _BudgetsDataNotifier _dataNotifier;

  BudgetPeriodType _selectedType = BudgetPeriodType.monthly;
  String _selectedPeriodKey = '';
  String _lastControllerMonthlyPeriodKey = '';
  DateTime? _customStart;
  DateTime? _customEnd;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = BudgetsViewModel(controller: widget.controller);
    _dataNotifier = _BudgetsDataNotifier();
    _selectedType = _viewModel.initialPeriodType();
    _selectedPeriodKey = _viewModel.initialPeriodKey();
    _lastControllerMonthlyPeriodKey = _selectedPeriodKey;
    final customRange = _viewModel.initialCustomRange(
      periodType: _selectedType,
      periodKey: _selectedPeriodKey,
    );
    _customStart = customRange.start;
    _customEnd = customRange.end;
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _viewModel.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final controllerPeriodKey = _viewModel.initialPeriodKey();
    if (_selectedType == BudgetPeriodType.monthly &&
        controllerPeriodKey != _lastControllerMonthlyPeriodKey &&
        !_viewModel.hasUnsavedChanges.value) {
      _selectedPeriodKey = controllerPeriodKey;
    }
    _lastControllerMonthlyPeriodKey = controllerPeriodKey;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant BudgetsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.manageCategoriesRequest != widget.manageCategoriesRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCategoryManagement();
      });
    }
  }

  void _schedulePruneOrphans(Set<String> keep) {
    final orphan = _controllers.keys.where((k) => !keep.contains(k)).toList();
    if (orphan.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in orphan) {
        _controllers.remove(key)?.dispose();
        _focusNodes.remove(key)?.dispose();
      }
    });
  }

  void _onDraftEdited([String _ = '']) {
    final rows = _dataNotifier.data?.rows ?? const <BudgetCategoryRow>[];
    _viewModel.updateUnsavedChanges(
      rows: rows,
      controllers: _controllers,
      periodType: _selectedType,
      periodKey: _selectedPeriodKey,
    );
  }

  Future<_BudgetScreenData> _loadScreenData({
    required AppLocalizations l10n,
    required bool hasSelectedPeriod,
    required BudgetPeriodType periodType,
    required String periodKey,
  }) async {
    final metrics = await _viewModel.buildPresentationMetrics(
      hasSelectedPeriod: hasSelectedPeriod,
      periodType: periodType,
      periodKey: periodKey,
    );
    final rows = await _viewModel.activityDrivenRows(
      hasSelectedPeriod: hasSelectedPeriod,
      periodType: periodType,
      periodKey: periodKey,
      spentByDisplay: metrics.spentByDisplay,
      categoryDisplayRenames: widget.controller.categoryDisplayRenames,
    );
    final keep = rows.map((r) => r.canonical).toSet();
    _viewModel.ensureControllers(
      canonicalKeys: keep,
      controllers: _controllers,
      focusNodes: _focusNodes,
    );
    _schedulePruneOrphans(keep);

    if (hasSelectedPeriod) {
      await _viewModel.syncControllersFromState(
        rows: rows,
        periodType: periodType,
        periodKey: periodKey,
        controllers: _controllers,
        focusNodes: _focusNodes,
      );
    }

    final categoryItems = await _viewModel.buildCategoryListItems(
      l10n: l10n,
      rows: rows,
      hasSelectedPeriod: hasSelectedPeriod,
      periodType: periodType,
      periodKey: periodKey,
      spentByIdentity: metrics.spentByIdentity,
      categoryDisplayRenames: widget.controller.categoryDisplayRenames,
    );

    return _BudgetScreenData(
      rows: rows,
      metrics: metrics,
      categoryItems: categoryItems,
    );
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    final keys = _viewModel.periodKeys(_selectedType);
    _selectedPeriodKey = _viewModel.normalizeSelectedPeriodKey(
      periodType: _selectedType,
      selectedPeriodKey: _selectedPeriodKey,
      availableKeys: keys,
    );
    final hasSelectedPeriod = _selectedPeriodKey.trim().isNotEmpty;

    _dataNotifier.setLoading();
    try {
      final data = await _loadScreenData(
        l10n: context.l10n,
        hasSelectedPeriod: hasSelectedPeriod,
        periodType: _selectedType,
        periodKey: _selectedPeriodKey,
      );
      if (!mounted || generation != _loadGeneration) return;
      _dataNotifier.setData(data);
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _dataNotifier.setError(error);
    }
  }

  void _activatePeriod(BudgetPeriodType type, String key) {
    if (key.trim().isEmpty) return;
    widget.controller.setActiveBudgetPeriod(type: type, key: key);
  }

  Future<bool> _confirmPeriodSwitchIfNeeded() async {
    if (!_viewModel.hasUnsavedChanges.value) return true;

    final l10n = context.l10n;
    final choice = await showDialog<_PeriodSwitchChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.budgetsScreenUnsavedChangesTitle),
          content: Text(l10n.budgetsScreenUnsavedChangesContent),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PeriodSwitchChoice.cancel),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PeriodSwitchChoice.discard),
              child: Text(l10n.commonDiscard),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PeriodSwitchChoice.save),
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
    );
    if (!mounted) return false;

    switch (choice) {
      case _PeriodSwitchChoice.save:
        return _save(_dataNotifier.data?.rows ?? const <BudgetCategoryRow>[]);
      case _PeriodSwitchChoice.discard:
        _viewModel.clearUnsavedChanges();
        return true;
      case _PeriodSwitchChoice.cancel:
      case null:
        return false;
    }
  }

  Future<void> _onPeriodTypeChanged(BudgetPeriodType type) async {
    if (!await _confirmPeriodSwitchIfNeeded()) return;

    final change = _viewModel.resolvePeriodTypeChange(
      nextType: type,
      currentPeriodKey: _selectedPeriodKey,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    setState(() {
      _selectedType = type;
      _selectedPeriodKey = change.periodKey;
      _customStart = change.customStart;
      _customEnd = change.customEnd;
    });
    _activatePeriod(type, change.periodKey);
    await _loadData();
  }

  Future<void> _pickMonthly() async {
    final picked = await _viewModel.openMonthYearPicker(
      context: context,
      initialKey: _selectedPeriodKey,
    );
    if (!mounted || picked == null) return;
    if (!await _confirmPeriodSwitchIfNeeded()) return;

    setState(() => _selectedPeriodKey = picked);
    _activatePeriod(BudgetPeriodType.monthly, picked);
    await _loadData();
  }

  Future<void> _pickWeeklyStartDate() async {
    final initial =
        _viewModel.parseDateKey(_selectedPeriodKey) ?? DateTime.now();
    final picked = await _viewModel.showPremiumDatePicker(
      context: context,
      initialDate: initial,
    );
    if (!mounted || picked == null) return;
    if (!await _confirmPeriodSwitchIfNeeded()) return;

    final key = widget.controller.budgetWeekStartKey(picked);
    setState(() => _selectedPeriodKey = key);
    _activatePeriod(BudgetPeriodType.weekly, key);
    await _loadData();
  }

  Future<void> _pickCustomDate({required bool start}) async {
    final initial =
        (start ? _customStart : _customEnd) ??
        _customStart ??
        _customEnd ??
        DateTime.now();
    final picked = await _viewModel.showPremiumDatePicker(
      context: context,
      initialDate: initial,
    );
    if (!mounted || picked == null) return;
    if (!await _confirmPeriodSwitchIfNeeded()) return;

    setState(() {
      if (start) {
        _customStart = DateTime(picked.year, picked.month, picked.day);
      } else {
        _customEnd = DateTime(picked.year, picked.month, picked.day);
      }
      if (_customStart != null && _customEnd != null) {
        _selectedPeriodKey = widget.controller.ensureCustomBudgetPeriod(
          _customStart!,
          _customEnd!,
        );
      }
    });
    if (_customStart != null && _customEnd != null) {
      _activatePeriod(BudgetPeriodType.custom, _selectedPeriodKey);
      await _loadData();
    }
  }

  Future<bool> _save(List<BudgetCategoryRow> rows) async {
    if (_selectedPeriodKey.trim().isEmpty) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _viewModel.buildDraft(rows: rows, controllers: _controllers);
    final ok = await widget.controller.commitBudgetDraft(
      _selectedType,
      _selectedPeriodKey,
      draft,
    );
    if (!mounted) return false;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.budgetsScreenSaveFailedSnack)),
      );
      return false;
    }
    _viewModel.clearUnsavedChanges();
    await _loadData();
    if (!mounted) return false;
    final periodLabel = _viewModel.periodDisplayLabel(
      periodType: _selectedType,
      periodKey: _selectedPeriodKey,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.budgetsScreenSavedSnack(periodLabel)),
      ),
    );
    return true;
  }

  Future<void> _openCategoryManagement() async {
    await showClarityAdaptiveOverlay<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: !isClarityDesktopLayout(context),
      dialogMaxWidth: 840,
      dialogMaxHeight: 720,
      builder: (overlayContext) {
        final desktop = isClarityDesktopLayout(overlayContext);
        final sheet = CategoryManagementSheet(controller: widget.controller);
        if (desktop) {
          return SizedBox(height: 680, child: sheet);
        }
        return FractionallySizedBox(heightFactor: 0.92, child: sheet);
      },
    );
    if (!mounted) return;
    await _loadData();
  }

  void _openCategoryTransactions(String category) {
    final month = budgetsCategoryDetailMonth(
      periodType: _selectedType,
      periodKey: _selectedPeriodKey,
    );
    final performance = _dataNotifier.data?.metrics.performance;
    if (month == null || performance == null) return;
    openBudgetsCategoryDetail(
      context: context,
      dashboardController: widget.dashboardController,
      transactionController: widget.transactionController,
      performance: performance,
      referenceMonth: month,
      category: category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final compactButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: cs.outline.withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.30),
    );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final keys = _viewModel.periodKeys(_selectedType);
        _selectedPeriodKey = _viewModel.normalizeSelectedPeriodKey(
          periodType: _selectedType,
          selectedPeriodKey: _selectedPeriodKey,
          availableKeys: keys,
        );
        final hasSelectedPeriod = _selectedPeriodKey.trim().isNotEmpty;
        final rows = _dataNotifier.data?.rows ?? const <BudgetCategoryRow>[];
        final weeklyDate = _viewModel.parseDateKey(_selectedPeriodKey);
        final canAttemptSave = rows.isNotEmpty && hasSelectedPeriod;
        final canOpenCategory = budgetsCategoryDetailMonth(
              periodType: _selectedType,
              periodKey: _selectedPeriodKey,
            ) !=
            null;

        return _BudgetsScaffold(
          viewModel: _viewModel,
          dataNotifier: _dataNotifier,
          selectedType: _selectedType,
          selectedPeriodKey: _selectedPeriodKey,
          keys: keys,
          weeklyDate: weeklyDate,
          customStart: _customStart,
          customEnd: _customEnd,
          compactButtonStyle: compactButtonStyle,
          canAttemptSave: canAttemptSave,
          controllers: _controllers,
          focusNodes: _focusNodes,
          onManageCategories: _openCategoryManagement,
          onSave: _save,
          onPeriodTypeChanged: _onPeriodTypeChanged,
          onPickMonthly: _pickMonthly,
          onPickWeekly: _pickWeeklyStartDate,
          onPickCustomStart: () => _pickCustomDate(start: true),
          onPickCustomEnd: () => _pickCustomDate(start: false),
          onDraftEdited: _onDraftEdited,
          onCategoryTap: canOpenCategory ? _openCategoryTransactions : null,
        );
      },
    );
  }
}
