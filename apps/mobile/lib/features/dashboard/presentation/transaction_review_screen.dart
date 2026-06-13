import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/models/models.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_review.dart';
import '../../transactions/domain/transaction_resolution.dart';
import '../../transactions/presentation/widgets/transaction_category_dropdown.dart';
import '../domain/dashboard_snapshot.dart';

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class TransactionReviewScreen extends StatefulWidget {
  const TransactionReviewScreen({
    super.key,
    required this.controller,
    required this.transactionController,
    required this.scope,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final DashboardScope scope;

  @override
  State<TransactionReviewScreen> createState() =>
      _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  final _searchController = TextEditingController();
  var _loading = true;
  var _saving = false;
  Object? _error;
  List<ResolvedTransaction> _transactions = const [];
  Map<String, Account> _accountsById = const {};
  var _filter = _ReviewQueueFilter.all;
  final _selectedKeys = <String>{};

  bool get _isAccountScope => widget.scope is AccountDashboardScope;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    widget.controller.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_load);
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final model = await widget.controller.loadFinancialReadModel();
      if (!mounted) return;
      final resolved = model.resolvedTransactionsForScope(widget.scope);
      setState(() {
        _transactions = resolved
            .where(transactionNeedsReview)
            .toList(growable: false);
        _accountsById = model.accountsById;
        _selectedKeys.removeWhere(
          (key) => !_transactions.any((tx) => _reviewKey(tx) == key),
        );
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

  List<ResolvedTransaction> get _filteredTransactions {
    final query = _normalizeSearchText(_searchController.text);
    final rows = _transactions.where((transaction) {
      if (!_matchesFilter(transaction)) return false;
      if (query.isEmpty) return true;
      return _searchHaystack(transaction).contains(query);
    }).toList();
    rows.sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    return rows;
  }

  List<ResolvedTransaction> get _selectedTransactions {
    return _filteredTransactions
        .where((transaction) => _selectedKeys.contains(_reviewKey(transaction)))
        .toList(growable: false);
  }

  bool _matchesFilter(ResolvedTransaction transaction) {
    final reasons = transactionReviewReasons(transaction);
    return switch (_filter) {
      _ReviewQueueFilter.all => reasons.isNotEmpty,
      _ReviewQueueFilter.internalPayments => reasons.contains(
        TransactionReviewReason.internalPayment,
      ),
      _ReviewQueueFilter.manualRoles => reasons.contains(
        TransactionReviewReason.manualRole,
      ),
      _ReviewQueueFilter.ignored => reasons.contains(
        TransactionReviewReason.ignored,
      ),
    };
  }

  String _searchHaystack(ResolvedTransaction transaction) {
    final raw = transaction.transaction;
    final account = _accountsById[raw.accountId];
    return [
      raw.description,
      _displayCategory(transaction),
      _financialRoleLabel(transaction.financialRole),
      _shortDate(raw.date),
      formatMoney(raw.amount),
      if (account != null) account.displayName,
      if (account?.institution?.trim().isNotEmpty == true)
        account!.institution!,
      for (final reason in transactionReviewReasons(transaction))
        _reviewReasonLabel(reason),
    ].map(_normalizeSearchText).join(' ');
  }

  Future<void> _bulkSetCategory(String category) async {
    final transactions = _selectedTransactions
        .map((resolved) => resolved.transaction)
        .toList(growable: false);
    if (transactions.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.transactionController.bulkSetCategoryOverrides(
        transactions,
        category,
      );
      await _load();
      if (!mounted) return;
      setState(() => _selectedKeys.clear());
      messenger?.showSnackBar(
        SnackBar(content: Text('Updated ${transactions.length} transactions.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not update transactions: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleSelected(ResolvedTransaction transaction, bool selected) {
    final key = _reviewKey(transaction);
    setState(() {
      if (selected) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  void _selectFiltered() {
    setState(() {
      for (final transaction in _filteredTransactions) {
        _selectedKeys.add(_reviewKey(transaction));
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedKeys.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _filteredTransactions;
    final selectedCount = _selectedTransactions.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction review'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '${filtered.length} review items',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isAccountScope ? 'Account review queue' : 'Global review queue',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            _ReviewSearchField(controller: _searchController),
            const SizedBox(height: 12),
            _ReviewQueueFilterBar(
              selected: _filter,
              onSelected: (filter) {
                setState(() {
                  _filter = filter;
                  _selectedKeys.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            if (selectedCount > 0)
              _BulkReviewBar(
                selectedCount: selectedCount,
                categories:
                    widget.transactionController.allowedCategoryPickerLabels,
                saving: _saving,
                onSetCategory: _bulkSetCategory,
                onClear: _clearSelection,
              )
            else if (filtered.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _selectFiltered,
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text('Select visible'),
                ),
              ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ReviewEmptyState(
                message: 'Could not load review queue.',
                actionLabel: 'Retry',
                onAction: _load,
              )
            else if (filtered.isEmpty)
              const _ReviewEmptyState(message: 'No review items match.')
            else
              for (var i = 0; i < filtered.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _ReviewTransactionCard(
                  transaction: filtered[i],
                  account: _accountsById[filtered[i].transaction.accountId],
                  showAccount: !_isAccountScope,
                  selected: _selectedKeys.contains(_reviewKey(filtered[i])),
                  saving: _saving,
                  controller: widget.transactionController,
                  onSelected: (selected) =>
                      _toggleSelected(filtered[i], selected),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ReviewQueueFilterBar extends StatelessWidget {
  const _ReviewQueueFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final _ReviewQueueFilter selected;
  final ValueChanged<_ReviewQueueFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _ReviewQueueFilter.values)
          ChoiceChip(
            selected: selected == filter,
            avatar: Icon(_reviewFilterIcon(filter), size: 18),
            label: Text(_reviewFilterLabel(filter)),
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}

class _BulkReviewBar extends StatelessWidget {
  const _BulkReviewBar({
    required this.selectedCount,
    required this.categories,
    required this.saving,
    required this.onSetCategory,
    required this.onClear,
  });

  final int selectedCount;
  final List<String> categories;
  final bool saving;
  final ValueChanged<String> onSetCategory;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.78)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          PopupMenuButton<String>(
            enabled: !saving,
            tooltip: 'Set category',
            onSelected: onSetCategory,
            itemBuilder: (context) => [
              for (final category in categories)
                PopupMenuItem(value: category, child: Text(category)),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.category_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Set category'),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: saving ? null : onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReviewTransactionCard extends StatelessWidget {
  const _ReviewTransactionCard({
    required this.transaction,
    required this.account,
    required this.showAccount,
    required this.selected,
    required this.saving,
    required this.controller,
    required this.onSelected,
  });

  final ResolvedTransaction transaction;
  final Account? account;
  final bool showAccount;
  final bool selected;
  final bool saving;
  final TransactionUiController controller;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final raw = transaction.transaction;
    final amountColor = raw.amount < 0
        ? const Color(0xFFC41E3A)
        : raw.amount > 0
        ? const Color(0xFF1B7A4C)
        : cs.onSurface;
    final reasons = transactionReviewReasons(transaction);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.78)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: saving ? null : (value) => onSelected(value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        raw.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatMoney(raw.amount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    _shortDate(raw.date),
                    if (showAccount && account != null) account!.displayName,
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final reason in reasons)
                      _ReasonChip(label: _reviewReasonLabel(reason)),
                  ],
                ),
                const SizedBox(height: 10),
                TransactionCategoryField(
                  controller: controller,
                  transaction: raw,
                  displayCategory: _displayCategory(transaction),
                ),
                const SizedBox(height: 6),
                TransactionRoleField(controller: controller, transaction: raw),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReviewSearchField extends StatelessWidget {
  const _ReviewSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final outline = cs.outlineVariant.withValues(alpha: 0.78);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.search_rounded,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
        hintText: 'Search review queue',
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
      ),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.78)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.56)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

enum _ReviewQueueFilter { all, internalPayments, manualRoles, ignored }

String _reviewFilterLabel(_ReviewQueueFilter filter) {
  return switch (filter) {
    _ReviewQueueFilter.all => 'All',
    _ReviewQueueFilter.internalPayments => 'Internal payments',
    _ReviewQueueFilter.manualRoles => 'Manual roles',
    _ReviewQueueFilter.ignored => 'Ignored',
  };
}

IconData _reviewFilterIcon(_ReviewQueueFilter filter) {
  return switch (filter) {
    _ReviewQueueFilter.all => Icons.fact_check_outlined,
    _ReviewQueueFilter.internalPayments => Icons.swap_horiz_rounded,
    _ReviewQueueFilter.manualRoles => Icons.account_tree_outlined,
    _ReviewQueueFilter.ignored => Icons.visibility_off_outlined,
  };
}

String _reviewReasonLabel(TransactionReviewReason reason) {
  return switch (reason) {
    TransactionReviewReason.needsCategory => 'Category data issue',
    TransactionReviewReason.internalPayment => 'Possible internal payment',
    TransactionReviewReason.manualRole => 'Manual role',
    TransactionReviewReason.ignored => 'Ignored',
  };
}

String _displayCategory(ResolvedTransaction transaction) {
  final category = transaction.displayCategory.trim();
  return category.isEmpty ? 'Unknown' : category;
}

String _financialRoleLabel(FinancialRole role) {
  return switch (role) {
    FinancialRole.expense => 'Expense',
    FinancialRole.income => 'Income',
    FinancialRole.transfer => 'Transfer',
    FinancialRole.creditCardPayment => 'Credit card payment',
    FinancialRole.refund => 'Refund',
    FinancialRole.adjustment => 'Adjustment',
  };
}

String _shortDate(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}';
}

String _normalizeSearchText(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _reviewKey(ResolvedTransaction transaction) {
  final raw = transaction.transaction;
  return raw.fingerprint ?? transactionCategoryKey(raw);
}
