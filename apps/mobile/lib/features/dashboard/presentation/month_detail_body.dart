import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/layout/clarity_breakpoints.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/presentation/widgets/transaction_line_tile.dart';

class MonthDetailBody extends StatefulWidget {
  const MonthDetailBody({
    super.key,
    required this.lines,
    required this.monthDeleteProtectionMessage,
    required this.transactionController,
  });

  final List<BankStatementLine> lines;
  final String? monthDeleteProtectionMessage;
  final TransactionUiController transactionController;

  @override
  State<MonthDetailBody> createState() => _MonthDetailBodyState();
}

class _MonthDetailBodyState extends State<MonthDetailBody> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  List<BankStatementLine> get _visibleLines {
    final query = _normalize(_searchController.text);
    if (query.isEmpty) return widget.lines;
    return widget.lines.where((line) {
      final haystack = [
        line.transaction.description,
        line.suggestedCategory,
        formatMoney(line.transaction.amount),
        formatShortDate(line.transaction.date),
      ].map(_normalize).join(' ');
      return haystack.contains(query);
    }).toList();
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final lines = widget.lines;
    final visible = _visibleLines;
    final queryActive = _searchController.text.trim().isNotEmpty;
    final monthTotal = lines.fold<double>(
      0,
      (sum, e) => sum + e.transaction.amount,
    );
    final totalColor = monthTotal < 0
        ? ClarityColors.financeNegative
        : monthTotal > 0
        ? ClarityColors.financePositive
        : colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.monthDetailNetThisMonth,
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatMoney(monthTotal),
                style:
                    (!isClarityDesktopLayout(context)
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: totalColor,
                        ),
              ),
              const SizedBox(height: 4),
              Text(
                lines.length == 1
                    ? l10n.commonTransactionCountOne
                    : l10n.commonTransactionCount(lines.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.search_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            suffixIcon: queryActive
                ? IconButton(
                    tooltip: l10n.dashboardTransactionsClearFilters,
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            hintText: l10n.monthDetailSearchHint,
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.78),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.78),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.monthDeleteProtectionMessage case final message?) ...[
          _PlaidDeleteProtectionNotice(message: message),
          const SizedBox(height: 18),
        ],
        Text(
          l10n.dashboardTransactionsSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          ),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 26,
                  ),
                  child: Text(
                    queryActive
                        ? l10n.monthDetailNoSearchMatches
                        : l10n.monthDetailNoTransactionsLeft,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      TransactionLineTile(
                        transaction: visible[i].transaction,
                        displayCategory: visible[i].suggestedCategory,
                        transactionController: widget.transactionController,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PlaidDeleteProtectionNotice extends StatelessWidget {
  const _PlaidDeleteProtectionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.78)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.52),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.62),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
