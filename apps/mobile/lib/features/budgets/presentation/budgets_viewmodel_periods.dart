part of 'budgets_viewmodel.dart';

mixin BudgetsViewModelPeriods {
  BudgetUiController get controller;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  BudgetPeriodType initialPeriodType() => BudgetPeriodType.monthly;

  String initialPeriodKey() => yearMonthKey(controller.spendReference);

  ({DateTime? start, DateTime? end}) initialCustomRange({
    required BudgetPeriodType periodType,
    required String periodKey,
  }) {
    if (periodType != BudgetPeriodType.custom || periodKey.trim().isEmpty) {
      return (start: null, end: null);
    }
    final range = _budgetPeriodRangeFor(
      periodType: BudgetPeriodType.custom,
      periodKey: periodKey,
    );
    if (range == null) return (start: null, end: null);
    return (start: range.start, end: range.end);
  }

  List<String> periodKeys(BudgetPeriodType type) {
    return switch (type) {
      BudgetPeriodType.monthly => _monthlyKeysForPicker(),
      BudgetPeriodType.weekly => _weeklyKeysForPicker(),
      BudgetPeriodType.custom => const <String>[],
    };
  }

  String normalizeSelectedPeriodKey({
    required BudgetPeriodType periodType,
    required String selectedPeriodKey,
    required List<String> availableKeys,
  }) {
    if (periodType == BudgetPeriodType.weekly) {
      if (selectedPeriodKey.trim().isNotEmpty) return selectedPeriodKey;
      return controller.budgetWeekStartKey(DateTime.now());
    }
    if (periodType == BudgetPeriodType.monthly) {
      if (selectedPeriodKey.trim().isNotEmpty) return selectedPeriodKey;
      return availableKeys.isNotEmpty
          ? availableKeys.first
          : yearMonthKey(controller.spendReference);
    }
    if (selectedPeriodKey.trim().isEmpty && availableKeys.isNotEmpty) {
      return availableKeys.first;
    }
    if (selectedPeriodKey.trim().isNotEmpty &&
        !availableKeys.contains(selectedPeriodKey)) {
      return availableKeys.isNotEmpty ? availableKeys.first : '';
    }
    return selectedPeriodKey;
  }

  String periodDisplayLabel({
    required BudgetPeriodType periodType,
    required String periodKey,
  }) {
    if (periodType == BudgetPeriodType.monthly) {
      return formatYearMonthLabel(periodKey);
    }
    return _budgetPeriodLabel(periodType: periodType, periodKey: periodKey);
  }

  String monthName(int month) {
    if (month < 1 || month > 12) return '';
    return _months[month - 1];
  }

  DateTime? parseYearMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month, 1);
  }

  String yearMonthKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  DateTime? parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  String weeklyRangeLabel(String key) {
    final range = _budgetPeriodRangeFor(
      periodType: BudgetPeriodType.weekly,
      periodKey: key,
    );
    if (range == null) return key;
    return '${formatShortDate(range.start)} – ${formatShortDate(range.end)}';
  }

  String formatLongDate(DateTime date) {
    return '${monthName(date.month)} ${date.day}, ${date.year}';
  }

  BudgetPeriodChange resolvePeriodTypeChange({
    required BudgetPeriodType nextType,
    required String currentPeriodKey,
    required DateTime? customStart,
    required DateTime? customEnd,
  }) {
    var nextKey = '';
    var nextCustomStart = customStart;
    var nextCustomEnd = customEnd;

    if (nextType == BudgetPeriodType.custom) {
      if (customStart != null && customEnd != null) {
        nextKey = controller.ensureCustomBudgetPeriod(customStart, customEnd);
      } else {
        final customKeys = periodKeys(BudgetPeriodType.custom);
        if (customKeys.isNotEmpty) {
          nextKey = customKeys.first;
          final range = _budgetPeriodRangeFor(
            periodType: BudgetPeriodType.custom,
            periodKey: nextKey,
          );
          if (range != null) {
            nextCustomStart = range.start;
            nextCustomEnd = range.end;
          }
        }
      }
    } else if (nextType == BudgetPeriodType.weekly) {
      final parsedCurrent = parseDateKey(currentPeriodKey);
      nextKey = controller.budgetWeekStartKey(parsedCurrent ?? DateTime.now());
    } else {
      final keys = periodKeys(nextType);
      nextKey = keys.isNotEmpty ? keys.first : '';
    }

    return BudgetPeriodChange(
      periodKey: nextKey,
      customStart: nextCustomStart,
      customEnd: nextCustomEnd,
    );
  }

  BudgetPeriodRange? _budgetPeriodRangeFor({
    required BudgetPeriodType periodType,
    required String periodKey,
  }) {
    return switch (periodType) {
      BudgetPeriodType.monthly => _monthlyRange(periodKey),
      BudgetPeriodType.weekly => _weeklyRange(periodKey),
      BudgetPeriodType.custom => _customRange(periodKey),
    };
  }

  BudgetPeriodRange? _monthlyRange(String key) {
    final start = parseYearMonthKey(key);
    if (start == null) return null;
    return BudgetPeriodRange(
      start: start,
      end: DateTime(start.year, start.month + 1, 0),
    );
  }

  BudgetPeriodRange? _weeklyRange(String key) {
    final start = parseDateKey(key);
    if (start == null) return null;
    return BudgetPeriodRange(
      start: start,
      end: start.add(const Duration(days: 6)),
    );
  }

  BudgetPeriodRange? _customRange(String key) {
    final parts = key.split('_');
    if (parts.length != 2) return null;
    final start = parseDateKey(parts[0]);
    final end = parseDateKey(parts[1]);
    if (start == null || end == null) return null;
    return BudgetPeriodRange(start: start, end: end);
  }

  String _budgetPeriodLabel({
    required BudgetPeriodType periodType,
    required String periodKey,
  }) {
    final range = _budgetPeriodRangeFor(
      periodType: periodType,
      periodKey: periodKey,
    );
    if (range == null) return periodKey;
    return '${formatShortDate(range.start)} – ${formatShortDate(range.end)}';
  }

  List<String> _monthlyKeysForPicker() {
    final now = controller.spendReference;
    return List<String>.generate(24, (index) {
      final date = DateTime(now.year, now.month - 12 + index);
      return yearMonthKey(date);
    });
  }

  List<String> _weeklyKeysForPicker() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List<String>.generate(12, (index) {
      final date = monday.subtract(Duration(days: index * 7));
      return _dateKey(date);
    });
  }

  DateTime? _periodStartDate(BudgetPeriodType periodType, String periodKey) {
    return switch (periodType) {
      BudgetPeriodType.monthly => parseYearMonthKey(periodKey),
      BudgetPeriodType.weekly => parseDateKey(periodKey),
      BudgetPeriodType.custom => _customRange(periodKey)?.start,
    };
  }

  String _periodToDatabaseValue(BudgetPeriodType periodType) {
    return switch (periodType) {
      BudgetPeriodType.monthly => 'monthly',
      BudgetPeriodType.weekly => 'weekly',
      BudgetPeriodType.custom => 'custom',
    };
  }

  bool _sameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<DateTime?> showPremiumDatePicker({
    required BuildContext context,
    required DateTime initialDate,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: initialDate,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 2,
              backgroundColor: cs.surface,
              headerBackgroundColor: cs.surfaceContainerHighest,
              headerForegroundColor: cs.onSurface,
              dayStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              dayShape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              yearShape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              todayBorder: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<String?> openMonthYearPicker({
    required BuildContext context,
    required String initialKey,
  }) async {
    final initial = parseYearMonthKey(initialKey) ?? DateTime.now();
    var selected = initial;
    var shownYear = initial.year;
    return showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              titlePadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              title: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setModalState(() => shownYear = shownYear - 1),
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        '$shownYear',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setModalState(() => shownYear = shownYear + 1),
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              content: SizedBox(
                width: 286,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final monthDate = DateTime(shownYear, month, 1);
                    final isSelected =
                        selected.year == shownYear && selected.month == month;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        selected = monthDate;
                        Navigator.of(context).pop(yearMonthKey(monthDate));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.outline.withValues(alpha: 0.24),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.10)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthName(month).substring(0, 3),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String formatBudgetSeed(double value) {
  if (!value.isFinite || value < 0) return '';
  final rounded = value.round();
  if ((value - rounded).abs() < 1e-9) return rounded.toString();
  var text = value.toString();
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
