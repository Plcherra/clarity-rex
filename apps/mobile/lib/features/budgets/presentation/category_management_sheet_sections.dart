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
    final l10n = context.l10n;
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: ClarityDiamondLoader(
                    size: 52,
                    label: l10n.categorySheetLoadingLabel,
                  ),
                ),
              )
            else if (hasError)
              _CategoryEmptyState(
                message: l10n.categorySheetLoadError,
                actionLabel: l10n.commonRetry,
                onAction: onRetry,
              )
            else
              Expanded(child: _buildSection(theme, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, AppLocalizations l10n) {
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
        l10n: l10n,
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
        l10n: l10n,
      ),
      _CategoryManagementSection.auditTrail => _AuditTrailSection(
        auditEvents: auditEvents,
        l10n: l10n,
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
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.categorySheetHeaderTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.categorySheetClose,
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
    final l10n = context.l10n;
    return SegmentedButton<_CategoryManagementSection>(
      segments: [
        ButtonSegment(
          value: _CategoryManagementSection.categories,
          icon: const Icon(Icons.category_outlined),
          label: Text(l10n.commonCategories),
        ),
        ButtonSegment(
          value: _CategoryManagementSection.merchantRules,
          icon: const Icon(Icons.storefront_outlined),
          label: Text(l10n.commonRules),
        ),
        ButtonSegment(
          value: _CategoryManagementSection.auditTrail,
          icon: const Icon(Icons.history_rounded),
          label: Text(l10n.commonHistory),
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
    required this.l10n,
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
  final AppLocalizations l10n;

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
            label: Text(l10n.categorySheetAddCustomCategory),
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
        _SectionLabel(text: l10n.categorySheetSavedCategoriesLabel),
        const SizedBox(height: 8),
        if (savedCategories.isEmpty)
          _CategoryEmptyState(message: l10n.categorySheetNoSavedCategories)
        else
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            rows[index],
          ],
        const SizedBox(height: 14),
        Text(
          l10n.categorySheetBuiltInHint(kSelectableSpendCategories.length),
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
    required this.l10n,
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
  final AppLocalizations l10n;

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
        _SectionLabel(text: l10n.categorySheetMerchantRulesLabel),
        const SizedBox(height: 8),
        if (merchantRules.isEmpty)
          _CategoryEmptyState(message: l10n.categorySheetNoMerchantRules)
        else
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            rows[index],
          ],
        const SizedBox(height: 14),
        Text(
          l10n.categorySheetMerchantRulesHint,
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
  const _AuditTrailSection({required this.auditEvents, required this.l10n});

  final List<FinancialAuditEvent> auditEvents;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionLabel(text: l10n.categorySheetRecentChangesLabel),
        const SizedBox(height: 8),
        if (auditEvents.isEmpty)
          _CategoryEmptyState(message: l10n.categorySheetNoAuditEvents)
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
