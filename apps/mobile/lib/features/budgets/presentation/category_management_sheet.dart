import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../categories/domain/category_normalization.dart';
import '../../finance/application/financial_read_model_service.dart';
import '../../finance/data/financial_audit_service.dart';
import '../../transactions/data/merchant_category_rule_service.dart';
import '../../transactions/domain/merchant_normalization.dart';
import '../../transactions/domain/spend_categories.dart';

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
    final name = await _showCategoryNameDialog(title: 'Add category');
    if (name == null) return;
    await _runSave(
      action: () => widget.controller.createBudgetCategory(name),
      successMessage: 'Category added.',
    );
  }

  Future<void> _renameCategory(CategoryRecord category) async {
    final name = await _showCategoryNameDialog(
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

  Future<String?> _showCategoryNameDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Category name'),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage categories',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<_CategoryManagementSection>(
              segments: const [
                ButtonSegment(
                  value: _CategoryManagementSection.categories,
                  icon: Icon(Icons.category_outlined),
                  label: Text('Categories'),
                ),
                ButtonSegment(
                  value: _CategoryManagementSection.merchantRules,
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('Rules'),
                ),
                ButtonSegment(
                  value: _CategoryManagementSection.auditTrail,
                  icon: Icon(Icons.history_rounded),
                  label: Text('History'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => setState(() => _section = selection.first),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _CategoryEmptyState(
                message: 'Could not load categories.',
                actionLabel: 'Retry',
                onAction: _load,
              )
            else if (_section == _CategoryManagementSection.categories) ...[
              FilledButton.icon(
                onPressed: _saving ? null : _addCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add custom category'),
              ),
              const SizedBox(height: 14),
              Text(
                'Saved categories',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (savedCategories.isEmpty)
                const _CategoryEmptyState(message: 'No saved categories yet.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: savedCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = savedCategories[index];
                      final custom = widget.controller.isCustomBudgetCategory(
                        category,
                      );
                      return _CategoryManagementRow(
                        category: category,
                        usage: _usageFor(category),
                        custom: custom,
                        saving: _saving,
                        onRename: custom
                            ? () => _renameCategory(category)
                            : null,
                        onDelete: custom
                            ? () => _deleteCategory(category)
                            : null,
                        onMerge: custom
                            ? () => _mergeCategory(category, savedCategories)
                            : null,
                        onToggleHidden: custom
                            ? () => _toggleHidden(category)
                            : null,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                'Built-in budget categories are always available: ${kSelectableSpendCategories.length}. Used custom categories must be merged or hidden before deletion.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.48),
                ),
              ),
            ] else if (_section ==
                _CategoryManagementSection.merchantRules) ...[
              Text(
                'Merchant rules',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (merchantRules.isEmpty)
                const _CategoryEmptyState(
                  message: 'No learned merchant rules yet.',
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: merchantRules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rule = merchantRules[index];
                      return _MerchantRuleManagementRow(
                        rule: rule,
                        category: categoryById[rule.categoryId],
                        stats: _merchantRuleStatsFor(rule),
                        saving: _saving,
                        onEditCategory: () =>
                            _editMerchantRuleCategory(rule, savedCategories),
                        onToggleDisabled: () =>
                            _toggleMerchantRuleDisabled(rule),
                        onDelete: () => _deleteMerchantRule(rule),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                'Merchant rules affect future CSV imports. Editing a rule does not rewrite existing transactions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.48),
                ),
              ),
            ] else ...[
              Text(
                'Recent changes',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (_auditEvents.isEmpty)
                const _CategoryEmptyState(
                  message: 'No financial changes recorded yet.',
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _auditEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _AuditEventRow(event: _auditEvents[index]);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isManageableCategory(CategoryRecord category) {
    if (category.type != 'expense') return false;
    if (isUnresolvedCategoryLabel(category.name) ||
        isIgnoredCategoryLabel(category.name) ||
        isIncomeCategoryLabel(category.name)) {
      return false;
    }
    return true;
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

  String _merchantRuleTitle(MerchantCategoryRule rule) {
    final display = rule.merchantDisplay?.trim();
    if (display != null && display.isNotEmpty) return display;
    return rule.merchantKey;
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
