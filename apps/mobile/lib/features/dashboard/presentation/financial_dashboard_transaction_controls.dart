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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashboardTransactionsGroupByLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 0.6,
            color: cs.onSurface.withValues(alpha: 0.42),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ModeChip(
                label: l10n.dashboardTransactionsModeList,
                icon: Icons.view_list_outlined,
                selected: selected == _TransactionsViewMode.list,
                onTap: () => onSelected(_TransactionsViewMode.list),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: l10n.dashboardTransactionsModeMonths,
                icon: Icons.calendar_month_outlined,
                selected: selected == _TransactionsViewMode.months,
                onTap: () => onSelected(_TransactionsViewMode.months),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: l10n.dashboardTransactionsModeCategories,
                icon: Icons.category_outlined,
                selected: selected == _TransactionsViewMode.categories,
                onTap: () => onSelected(_TransactionsViewMode.categories),
              ),
            ],
          ),
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
    required this.accounts,
    required this.isAccountScope,
    required this.accountIds,
    required this.timeFilter,
    required this.sortMode,
    required this.onAccountIdsChanged,
    required this.onTimeChanged,
    required this.onSortChanged,
  });

  final List<Account> accounts;
  final bool isAccountScope;
  final Set<String> accountIds;
  final _TransactionsTimeFilter timeFilter;
  final _TransactionsSortMode sortMode;
  final ValueChanged<Set<String>> onAccountIdsChanged;
  final ValueChanged<_TransactionsTimeFilter> onTimeChanged;
  final ValueChanged<_TransactionsSortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chips = <Widget>[
      if (!isAccountScope)
        _AccountMultiFilterChip(
          accounts: accounts,
          selectedIds: accountIds,
          onChanged: onAccountIdsChanged,
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
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
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
