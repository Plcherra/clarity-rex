part of 'financial_dashboard_view.dart';

class _TransactionsModePicker extends StatelessWidget {
  const _TransactionsModePicker({
    required this.selected,
    required this.onSelected,
  });

  final _TransactionsViewMode selected;
  final ValueChanged<_TransactionsViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ModeChip(
          label: l10n.dashboardTransactionsModeMonths,
          icon: Icons.calendar_month_outlined,
          selected: selected == _TransactionsViewMode.months,
          onTap: () => onSelected(_TransactionsViewMode.months),
        ),
        _ModeChip(
          label: l10n.dashboardTransactionsModeCategories,
          icon: Icons.category_outlined,
          selected: selected == _TransactionsViewMode.categories,
          onTap: () => onSelected(_TransactionsViewMode.categories),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      selectedColor: _dashboardSelected(context),
      backgroundColor: _dashboardPanel(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: _dashboardOutline(context)),
      ),
    );
  }
}

class _TransactionSearchField extends StatelessWidget {
  const _TransactionSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.search_rounded,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
        hintText: context.l10n.dashboardTransactionsSearchHint,
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _dashboardOutline(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _dashboardOutline(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _InlineFilterBar extends StatelessWidget {
  const _InlineFilterBar({
    required this.categories,
    required this.accounts,
    required this.isAccountScope,
    required this.category,
    required this.accountId,
    required this.timeFilter,
    required this.sortMode,
    required this.roleFilter,
    required this.onCategoryChanged,
    required this.onAccountChanged,
    required this.onTimeChanged,
    required this.onSortChanged,
    required this.onRoleChanged,
  });

  final List<String> categories;
  final List<Account> accounts;
  final bool isAccountScope;
  final String? category;
  final String? accountId;
  final _TransactionsTimeFilter timeFilter;
  final _TransactionsSortMode sortMode;
  final FinancialRole? roleFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<_TransactionsTimeFilter> onTimeChanged;
  final ValueChanged<_TransactionsSortMode> onSortChanged;
  final ValueChanged<FinancialRole?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PopupFilterChip<String?>(
          label: category ?? l10n.dashboardTransactionsFilterCategory,
          active: category != null,
          icon: Icons.category_outlined,
          values: [null, ...categories],
          labelFor: (value) =>
              value ?? l10n.dashboardTransactionsFilterAllCategories,
          onSelected: onCategoryChanged,
        ),
        if (!isAccountScope)
          _PopupFilterChip<String?>(
            label: _accountLabel(accountId) ?? l10n.dashboardTransactionsFilterAccount,
            active: accountId != null,
            icon: Icons.account_balance_outlined,
            values: [null, ...accounts.map((a) => a.id)],
            labelFor: (value) =>
                _accountLabel(value) ?? l10n.dashboardTransactionsFilterAllAccounts,
            onSelected: onAccountChanged,
          ),
        _PopupFilterChip<_TransactionsTimeFilter>(
          label: _timeLabel(l10n, timeFilter),
          active: timeFilter != _TransactionsTimeFilter.all,
          icon: Icons.date_range_outlined,
          values: _TransactionsTimeFilter.values,
          labelFor: (value) => _timeLabel(l10n, value),
          onSelected: onTimeChanged,
        ),
        _PopupFilterChip<_TransactionsSortMode>(
          label: _sortLabel(l10n, sortMode),
          active: sortMode != _TransactionsSortMode.newest,
          icon: Icons.sort_rounded,
          values: _TransactionsSortMode.values,
          labelFor: (value) => _sortLabel(l10n, value),
          onSelected: onSortChanged,
        ),
        _PopupFilterChip<FinancialRole?>(
          label: roleFilter == null
              ? l10n.dashboardTransactionsFilterRole
              : _financialRoleLabel(l10n, roleFilter!),
          active: roleFilter != null,
          icon: Icons.account_tree_outlined,
          values: <FinancialRole?>[null, ...FinancialRole.values],
          labelFor: (value) => value == null
              ? l10n.dashboardTransactionsFilterAllRoles
              : _financialRoleLabel(l10n, value),
          onSelected: onRoleChanged,
        ),
      ],
    );
  }

  String? _accountLabel(String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account.displayName;
    }
    return null;
  }
}

class _PopupFilterChip<T> extends StatelessWidget {
  const _PopupFilterChip({
    required this.label,
    required this.active,
    required this.icon,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final IconData icon;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem<T>(value: value, child: Text(labelFor(value))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _dashboardSelected(context) : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _dashboardOutline(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.72)),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
