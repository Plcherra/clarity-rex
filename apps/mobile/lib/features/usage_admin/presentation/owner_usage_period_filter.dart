import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_filter.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef UsageAdminFilterChanged = void Function(UsageAdminFilter filter);

final class OwnerUsagePeriodFilter extends StatelessWidget {
  const OwnerUsagePeriodFilter({
    required this.filter,
    required this.onChanged,
    super.key,
  });

  final UsageAdminFilter filter;
  final UsageAdminFilterChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.usageAdminFilterTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<UsageAdminPeriodKind>(
          segments: [
            ButtonSegment(
              value: UsageAdminPeriodKind.all,
              label: Text(l10n.usageAdminFilterAll),
            ),
            ButtonSegment(
              value: UsageAdminPeriodKind.year,
              label: Text(l10n.usageAdminFilterYear),
            ),
            ButtonSegment(
              value: UsageAdminPeriodKind.month,
              label: Text(l10n.usageAdminFilterMonth),
            ),
            ButtonSegment(
              value: UsageAdminPeriodKind.day,
              label: Text(l10n.usageAdminFilterDay),
            ),
          ],
          selected: {filter.period},
          onSelectionChanged: (selection) {
            onChanged(filter.copyWith(period: selection.first));
          },
        ),
        if (filter.period != UsageAdminPeriodKind.all) ...[
          const SizedBox(height: 12),
          _PeriodControls(
            filter: filter,
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          l10n.usageAdminFilterRangeLabel(
            _periodLabel(l10n, filter),
            _formatDate(l10n, filter.rangeStart),
            _formatDate(l10n, filter.rangeEnd),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  String _periodLabel(AppLocalizations l10n, UsageAdminFilter value) {
    switch (value.period) {
      case UsageAdminPeriodKind.all:
        return l10n.usageAdminFilterAll;
      case UsageAdminPeriodKind.year:
        return value.year.toString();
      case UsageAdminPeriodKind.month:
        return DateFormat.yMMMM().format(DateTime(value.year, value.month));
      case UsageAdminPeriodKind.day:
        return DateFormat.yMMMd().format(value.day);
    }
  }

  String _formatDate(AppLocalizations l10n, DateTime value) {
    return DateFormat.yMMMd(l10n.localeName).format(value);
  }
}

class _PeriodControls extends StatelessWidget {
  const _PeriodControls({
    required this.filter,
    required this.onChanged,
  });

  final UsageAdminFilter filter;
  final UsageAdminFilterChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    switch (filter.period) {
      case UsageAdminPeriodKind.year:
        return _YearStepper(
          year: filter.year,
          onChanged: (year) => onChanged(filter.copyWith(year: year)),
        );
      case UsageAdminPeriodKind.month:
        return Row(
          children: [
            Expanded(
              child: _YearStepper(
                year: filter.year,
                onChanged: (year) => onChanged(filter.copyWith(year: year)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthStepper(
                year: filter.year,
                month: filter.month,
                onChanged: (month) => onChanged(filter.copyWith(month: month)),
              ),
            ),
          ],
        );
      case UsageAdminPeriodKind.day:
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: filter.day,
                firstDate: DateTime(2026, 1, 1),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                onChanged(filter.copyWith(day: picked));
              }
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(DateFormat.yMMMd(l10n.localeName).format(filter.day)),
          ),
        );
      case UsageAdminPeriodKind.all:
        return const SizedBox.shrink();
    }
  }
}

class _YearStepper extends StatelessWidget {
  const _YearStepper({
    required this.year,
    required this.onChanged,
  });

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: year > 2026 ? () => onChanged(year - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            year.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: year < DateTime.now().year
              ? () => onChanged(year + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
    required this.year,
    required this.month,
    required this.onChanged,
  });

  final int year;
  final int month;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxMonth = year == now.year ? now.month : 12;
    final label = DateFormat.MMMM().format(DateTime(2026, month));
    return Row(
      children: [
        IconButton(
          onPressed: month > 1 ? () => onChanged(month - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: month < maxMonth ? () => onChanged(month + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

String usageAdminPeriodHeading(AppLocalizations l10n, UsageAdminFilter filter) {
  switch (filter.period) {
    case UsageAdminPeriodKind.all:
      return l10n.usageAdminPlatformAllTime;
    case UsageAdminPeriodKind.year:
      return l10n.usageAdminPlatformYear(filter.year);
    case UsageAdminPeriodKind.month:
      return l10n.usageAdminPlatformMonth(
        DateFormat.yMMMM().format(DateTime(filter.year, filter.month)),
      );
    case UsageAdminPeriodKind.day:
      return l10n.usageAdminPlatformDay(
        DateFormat.yMMMd(l10n.localeName).format(filter.day),
      );
  }
}
