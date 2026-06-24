import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../categories/domain/category_normalization.dart';
import '../../finance/application/financial_read_model_service.dart';
import '../../finance/data/financial_audit_service.dart';
import '../../transactions/data/merchant_category_rule_service.dart';
import '../../transactions/domain/merchant_normalization.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../../widgets/clarity_diamond_loader.dart';

part 'category_management_sheet_widgets.dart';
part 'category_management_sheet_sections.dart';
part 'category_management_sheet_dialogs.dart';
part 'category_management_sheet_helpers.dart';

class CategoryManagementSheet extends StatefulWidget {
  const CategoryManagementSheet({super.key, required this.controller});

  final BudgetUiController controller;

  @override
  State<CategoryManagementSheet> createState() =>
      _CategoryManagementSheetState();
}

class _CategoryManagementSheetState extends State<CategoryManagementSheet> {
  FinancialReadModel? _model;
  List<FinancialAuditEvent> _auditEvents = const [];
  Object? _error;
  var _loading = true;
  var _saving = false;
  var _section = _CategoryManagementSection.categories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final model = await widget.controller.loadFinancialReadModel();
      var auditEvents = const <FinancialAuditEvent>[];
      try {
        auditEvents = await widget.controller.fetchRecentFinancialAuditEvents();
      } on Object {
        auditEvents = const <FinancialAuditEvent>[];
      }
      if (!mounted) return;
      setState(() {
        _model = model;
        _auditEvents = auditEvents;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = await _showCategoryNameDialog(context, title: 'Add category');
    if (name == null) return;
    await _runSave(
      action: () => widget.controller.createBudgetCategory(name),
      successMessage: 'Category added.',
    );
  }

  Future<void> _renameCategory(CategoryRecord category) async {
    final name = await _showCategoryNameDialog(
      context,
      title: 'Rename category',
      initialValue: category.name,
    );
    if (name == null || name == category.name) return;
    await _runSave(
      action: () => widget.controller.renameBudgetCategory(category.name, name),
      successMessage: 'Category renamed.',
    );
  }

  Future<void> _deleteCategory(CategoryRecord category) async {
    final usage = _usageFor(category);
    if (usage.hasAny) {
      await _showUsedCategoryBlockedDialog(category, usage);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${category.name}" is not used by transactions, budgets, or merchant rules. Delete it from saved custom categories?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runSave(
      action: () => widget.controller.deleteBudgetCategory(category.name),
      successMessage: 'Category deleted.',
    );
  }

  Future<void> _toggleHidden(CategoryRecord category) async {
    await _runSave(
      action: () =>
          widget.controller.setBudgetCategoryHidden(category, !category.hidden),
      successMessage: category.hidden
          ? 'Category shown in pickers.'
          : 'Category hidden from pickers.',
    );
  }

  Future<void> _mergeCategory(
    CategoryRecord source,
    List<CategoryRecord> categories,
  ) async {
    final model = _model;
    if (model == null) return;
    final targets = categories
        .where((category) => category.id != source.id && !category.hidden)
        .toList(growable: false);
    final target = await _showMergeTargetDialog(source, targets);
    if (target == null) return;
    if (!mounted) return;
    final usage = _usageFor(source);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge category?'),
        content: Text(
          'Merge "${source.name}" into "${target.name}"? This will move ${usage.label} to "${target.name}" and delete "${source.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runSave(
      action: () => widget.controller.mergeBudgetCategory(
        source: source,
        target: target,
        model: model,
      ),
      successMessage: 'Category merged.',
    );
  }

  Future<void> _showUsedCategoryBlockedDialog(
    CategoryRecord category,
    _CategoryUsageStats usage,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Category is in use'),
        content: Text(
          '"${category.name}" is used by ${usage.label}. Merge it into another category or hide it from pickers instead of deleting it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<CategoryRecord?> _showMergeTargetDialog(
    CategoryRecord source,
    List<CategoryRecord> targets,
  ) {
    return _showCategoryPickerDialog(
      emptyMessage: 'No visible target category to merge into.',
      title: 'Merge "${source.name}" into',
      categories: targets,
    );
  }

  Future<CategoryRecord?> _showCategoryPickerDialog({
    required String emptyMessage,
    required String title,
    required List<CategoryRecord> categories,
  }) async {
    final targets =
        categories.where((category) => !category.hidden).toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (targets.isEmpty) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(emptyMessage)));
      return null;
    }
    return showDialog<CategoryRecord>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: targets.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final target = targets[index];
              final usage = _usageFor(target);
              return ListTile(
                title: Text(target.name),
                subtitle: Text(usage.label),
                onTap: () => Navigator.of(context).pop(target),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _editMerchantRuleCategory(
    MerchantCategoryRule rule,
    List<CategoryRecord> categories,
  ) async {
    final category = await _showCategoryPickerDialog(
      emptyMessage: 'No visible category is available for this rule.',
      title: 'Set merchant rule category',
      categories: categories,
    );
    if (category == null || category.id == rule.categoryId) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update future imports?'),
        content: Text(
          'Future "${_merchantRuleTitle(rule)}" imports will use "${category.name}". Existing transactions will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update rule'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runSave(
      action: () => widget.controller.setMerchantRuleCategory(
        rule: rule,
        category: category,
      ),
      successMessage: 'Merchant rule updated.',
    );
  }

  Future<void> _toggleMerchantRuleDisabled(MerchantCategoryRule rule) async {
    final nextDisabled = !rule.disabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextDisabled ? 'Disable rule?' : 'Enable rule?'),
        content: Text(
          nextDisabled
              ? 'Future "${_merchantRuleTitle(rule)}" imports will stop using this learned category rule.'
              : 'Future "${_merchantRuleTitle(rule)}" imports will use this learned category rule again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(nextDisabled ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runSave(
      action: () => widget.controller.setMerchantRuleDisabled(
        rule: rule,
        disabled: nextDisabled,
      ),
      successMessage: nextDisabled
          ? 'Merchant rule disabled.'
          : 'Merchant rule enabled.',
    );
  }

  Future<void> _deleteMerchantRule(MerchantCategoryRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete merchant rule?'),
        content: Text(
          'Future "${_merchantRuleTitle(rule)}" imports will no longer use this learned category rule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runSave(
      action: () => widget.controller.deleteMerchantRule(rule),
      successMessage: 'Merchant rule deleted.',
    );
  }

  Future<void> _runSave({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await action();
      await _load();
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not save changes: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final savedCategories =
        (model?.categories ?? const <CategoryRecord>[])
            .where(_isManageableCategory)
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final merchantRules =
        (model?.merchantCategoryRules ?? const <MerchantCategoryRule>[]).toList(
          growable: false,
        )..sort(
          (a, b) => _merchantRuleTitle(
            a,
          ).toLowerCase().compareTo(_merchantRuleTitle(b).toLowerCase()),
        );
    final categoryById = {
      for (final category in model?.categories ?? const <CategoryRecord>[])
        category.id: category,
    };

    return _CategoryManagementContent(
      section: _section,
      loading: _loading,
      hasError: _error != null,
      saving: _saving,
      savedCategories: savedCategories,
      merchantRules: merchantRules,
      categoryById: categoryById,
      auditEvents: _auditEvents,
      onClose: () => Navigator.of(context).pop(),
      onRetry: _load,
      onSectionChanged: (section) => setState(() => _section = section),
      onAddCategory: _addCategory,
      isCustomCategory: widget.controller.isCustomBudgetCategory,
      categoryUsageFor: _usageFor,
      merchantRuleStatsFor: _merchantRuleStatsFor,
      onRenameCategory: _renameCategory,
      onDeleteCategory: _deleteCategory,
      onMergeCategory: _mergeCategory,
      onToggleCategoryHidden: _toggleHidden,
      onEditMerchantRuleCategory: _editMerchantRuleCategory,
      onToggleMerchantRuleDisabled: _toggleMerchantRuleDisabled,
      onDeleteMerchantRule: _deleteMerchantRule,
    );
  }

  _CategoryUsageStats _usageFor(CategoryRecord category) {
    final model = _model;
    if (model == null) return const _CategoryUsageStats();
    final categoryKey = categoryRecordKey(
      name: category.name,
      normalizedName: category.normalizedName,
    );
    var transactionCount = 0;
    for (final transaction in model.transactionRecords) {
      if (transaction.categoryId == category.id) transactionCount += 1;
    }
    var budgetCount = 0;
    for (final budget in model.budgets) {
      if (budget.categoryId == category.id ||
          (budget.categoryId == null && budget.categoryKey == categoryKey)) {
        budgetCount += 1;
      }
    }
    var merchantRuleCount = 0;
    for (final rule in model.merchantCategoryRules) {
      if (rule.categoryId == category.id) merchantRuleCount += 1;
    }
    return _CategoryUsageStats(
      transactionCount: transactionCount,
      budgetCount: budgetCount,
      merchantRuleCount: merchantRuleCount,
    );
  }

  _MerchantRuleStats _merchantRuleStatsFor(MerchantCategoryRule rule) {
    final keys = <String>{rule.merchantKey.trim().toLowerCase()};
    keys.addAll(rule.aliases.map((alias) => alias.trim().toLowerCase()));
    keys.removeWhere((key) => key.isEmpty);
    if (keys.isEmpty) return const _MerchantRuleStats();

    var transactionCount = 0;
    DateTime? latestDate;
    for (final transaction
        in _model?.transactionRecords ?? const <TransactionRecord>[]) {
      final key = merchantKeyLowerFromDescription(
        transaction.description ?? transaction.merchant ?? '',
      );
      if (!keys.contains(key)) continue;
      transactionCount += 1;
      if (latestDate == null || transaction.date.isAfter(latestDate)) {
        latestDate = transaction.date;
      }
    }
    return _MerchantRuleStats(
      transactionCount: transactionCount,
      latestTransactionDate: latestDate,
    );
  }
}
