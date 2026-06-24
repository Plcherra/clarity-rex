part of 'category_management_sheet.dart';

typedef _CategoryCustomResolver = bool Function(CategoryRecord category);
typedef _CategoryUsageResolver =
    _CategoryUsageStats Function(CategoryRecord category);
typedef _MerchantRuleStatsResolver =
    _MerchantRuleStats Function(MerchantCategoryRule rule);

class _CategoryManagementContent extends StatelessWidget {
  const _CategoryManagementContent({
    required this.section,
    required this.loading,
    required this.hasError,
    required this.saving,
    required this.savedCategories,
    required this.merchantRules,
    required this.categoryById,
    required this.auditEvents,
    required this.onClose,
    required this.onRetry,
    required this.onSectionChanged,
    required this.onAddCategory,
    required this.isCustomCategory,
    required this.categoryUsageFor,
    required this.merchantRuleStatsFor,
    required this.onRenameCategory,
    required this.onDeleteCategory,
    required this.onMergeCategory,
    required this.onToggleCategoryHidden,
    required this.onEditMerchantRuleCategory,
    required this.onToggleMerchantRuleDisabled,
    required this.onDeleteMerchantRule,
  });

  final _CategoryManagementSection section;
  final bool loading;
  final bool hasError;
  final bool saving;
  final List<CategoryRecord> savedCategories;
  final List<MerchantCategoryRule> merchantRules;
  final Map<String, CategoryRecord> categoryById;
  final List<FinancialAuditEvent> auditEvents;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final ValueChanged<_CategoryManagementSection> onSectionChanged;
  final VoidCallback onAddCategory;
  final _CategoryCustomResolver isCustomCategory;
  final _CategoryUsageResolver categoryUsageFor;
  final _MerchantRuleStatsResolver merchantRuleStatsFor;
  final Future<void> Function(CategoryRecord category) onRenameCategory;
  final Future<void> Function(CategoryRecord category) onDeleteCategory;
  final Future<void> Function(CategoryRecord source, List<CategoryRecord> all)
  onMergeCategory;
  final Future<void> Function(CategoryRecord category) onToggleCategoryHidden;
  final Future<void> Function(
    MerchantCategoryRule rule,
    List<CategoryRecord> categories,
  )
  onEditMerchantRuleCategory;
  final Future<void> Function(MerchantCategoryRule rule)
  onToggleMerchantRuleDisabled;
  final Future<void> Function(MerchantCategoryRule rule) onDeleteMerchantRule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryManagementHeader(onClose: onClose),
            const SizedBox(height: 8),
            _CategoryManagementTabs(
              section: section,
              saving: saving,
              onChanged: onSectionChanged,
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: ClarityDiamondLoader(
                    size: 52,
                    label: 'Loading categories',
                  ),
                ),
              )
            else if (hasError)
              _CategoryEmptyState(
                message: 'Could not load categories.',
                actionLabel: 'Retry',
                onAction: onRetry,
              )
            else
              Expanded(child: _buildSection(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme) {
    return switch (section) {
      _CategoryManagementSection.categories => _CategoryListSection(
        saving: saving,
        savedCategories: savedCategories,
        onAddCategory: onAddCategory,
        isCustomCategory: isCustomCategory,
        categoryUsageFor: categoryUsageFor,
        onRenameCategory: onRenameCategory,
        onDeleteCategory: onDeleteCategory,
        onMergeCategory: onMergeCategory,
        onToggleCategoryHidden: onToggleCategoryHidden,
      ),
      _CategoryManagementSection.merchantRules => _MerchantRulesSection(
        saving: saving,
        savedCategories: savedCategories,
        merchantRules: merchantRules,
        categoryById: categoryById,
        merchantRuleStatsFor: merchantRuleStatsFor,
        onEditMerchantRuleCategory: onEditMerchantRuleCategory,
        onToggleMerchantRuleDisabled: onToggleMerchantRuleDisabled,
        onDeleteMerchantRule: onDeleteMerchantRule,
      ),
      _CategoryManagementSection.auditTrail => _AuditTrailSection(
        auditEvents: auditEvents,
      ),
    };
  }
}

class _CategoryManagementHeader extends StatelessWidget {
  const _CategoryManagementHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _CategoryManagementTabs extends StatelessWidget {
  const _CategoryManagementTabs({
    required this.section,
    required this.saving,
    required this.onChanged,
  });

  final _CategoryManagementSection section;
  final bool saving;
  final ValueChanged<_CategoryManagementSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_CategoryManagementSection>(
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
      selected: {section},
      onSelectionChanged: saving
          ? null
          : (selection) => onChanged(selection.first),
    );
  }
}

class _CategoryListSection extends StatelessWidget {
  const _CategoryListSection({
    required this.saving,
    required this.savedCategories,
    required this.onAddCategory,
    required this.isCustomCategory,
    required this.categoryUsageFor,
    required this.onRenameCategory,
    required this.onDeleteCategory,
    required this.onMergeCategory,
    required this.onToggleCategoryHidden,
  });

  final bool saving;
  final List<CategoryRecord> savedCategories;
  final VoidCallback onAddCategory;
  final _CategoryCustomResolver isCustomCategory;
  final _CategoryUsageResolver categoryUsageFor;
  final Future<void> Function(CategoryRecord category) onRenameCategory;
  final Future<void> Function(CategoryRecord category) onDeleteCategory;
  final Future<void> Function(CategoryRecord source, List<CategoryRecord> all)
  onMergeCategory;
  final Future<void> Function(CategoryRecord category) onToggleCategoryHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = savedCategories
        .map((category) {
          final custom = isCustomCategory(category);
          return _CategoryManagementRow(
            category: category,
            usage: categoryUsageFor(category),
            custom: custom,
            saving: saving,
            onRename: custom ? () => onRenameCategory(category) : null,
            onDelete: custom ? () => onDeleteCategory(category) : null,
            onMerge: custom
                ? () => onMergeCategory(category, savedCategories)
                : null,
            onToggleHidden: custom
                ? () => onToggleCategoryHidden(category)
                : null,
          );
        })
        .toList(growable: false);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: saving ? null : onAddCategory,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add custom category'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface.withValues(alpha: 0.82),
              backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.36),
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.72),
              ),
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionLabel(text: 'Saved categories'),
        const SizedBox(height: 8),
        if (savedCategories.isEmpty)
          const _CategoryEmptyState(message: 'No saved categories yet.')
        else
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            rows[index],
          ],
        const SizedBox(height: 14),
        Text(
          'Built-in budget categories are always available: ${kSelectableSpendCategories.length}. Used custom categories must be merged or hidden before deletion.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.48),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MerchantRulesSection extends StatelessWidget {
  const _MerchantRulesSection({
    required this.saving,
    required this.savedCategories,
    required this.merchantRules,
    required this.categoryById,
    required this.merchantRuleStatsFor,
    required this.onEditMerchantRuleCategory,
    required this.onToggleMerchantRuleDisabled,
    required this.onDeleteMerchantRule,
  });

  final bool saving;
  final List<CategoryRecord> savedCategories;
  final List<MerchantCategoryRule> merchantRules;
  final Map<String, CategoryRecord> categoryById;
  final _MerchantRuleStatsResolver merchantRuleStatsFor;
  final Future<void> Function(
    MerchantCategoryRule rule,
    List<CategoryRecord> categories,
  )
  onEditMerchantRuleCategory;
  final Future<void> Function(MerchantCategoryRule rule)
  onToggleMerchantRuleDisabled;
  final Future<void> Function(MerchantCategoryRule rule) onDeleteMerchantRule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = merchantRules
        .map(
          (rule) => _MerchantRuleManagementRow(
            rule: rule,
            category: categoryById[rule.categoryId],
            stats: merchantRuleStatsFor(rule),
            saving: saving,
            onEditCategory: () =>
                onEditMerchantRuleCategory(rule, savedCategories),
            onToggleDisabled: () => onToggleMerchantRuleDisabled(rule),
            onDelete: () => onDeleteMerchantRule(rule),
          ),
        )
        .toList(growable: false);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionLabel(text: 'Merchant rules'),
        const SizedBox(height: 8),
        if (merchantRules.isEmpty)
          const _CategoryEmptyState(message: 'No learned merchant rules yet.')
        else
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            rows[index],
          ],
        const SizedBox(height: 14),
        Text(
          'Merchant rules affect future CSV imports. Editing a rule does not rewrite existing transactions.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.48),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AuditTrailSection extends StatelessWidget {
  const _AuditTrailSection({required this.auditEvents});

  final List<FinancialAuditEvent> auditEvents;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionLabel(text: 'Recent changes'),
        const SizedBox(height: 8),
        if (auditEvents.isEmpty)
          const _CategoryEmptyState(
            message: 'No financial changes recorded yet.',
          )
        else
          for (var index = 0; index < auditEvents.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _AuditEventRow(event: auditEvents[index]),
          ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.56),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
