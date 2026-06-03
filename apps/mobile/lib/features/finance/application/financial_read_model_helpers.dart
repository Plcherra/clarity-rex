part of 'financial_read_model_service.dart';

String _budgetIdentityForBudget(BudgetRecord budget) {
  return _budgetIdentity(
    categoryId: budget.categoryId,
    categoryKey: budget.categoryKey,
    displayLabel: budget.name,
  );
}

String _budgetIdentity({
  required String? categoryId,
  required String? categoryKey,
  required String displayLabel,
}) {
  final id = categoryId?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';
  final key = categoryKey?.trim().isNotEmpty == true
      ? categoryKey!.trim()
      : normalizedCategoryKey(displayLabel);
  if (key.isEmpty) return '';
  return 'key:$key';
}

int _compareStatementImports(
  AccountStatementImport a,
  AccountStatementImport b,
) {
  final endCompare = _nullableDateMicros(
    a.endDate,
  ).compareTo(_nullableDateMicros(b.endDate));
  if (endCompare != 0) return endCompare;
  final createdCompare = a.createdAt.microsecondsSinceEpoch.compareTo(
    b.createdAt.microsecondsSinceEpoch,
  );
  if (createdCompare != 0) return createdCompare;
  return a.importId.compareTo(b.importId);
}

int _nullableDateMicros(DateTime? value) {
  return value?.microsecondsSinceEpoch ?? -1;
}

bool _inRangeInclusive(DateTime date, DateTime start, DateTime end) {
  final value = DateTime(date.year, date.month, date.day);
  final rangeStart = DateTime(start.year, start.month, start.day);
  final rangeEnd = DateTime(end.year, end.month, end.day);
  return !value.isBefore(rangeStart) && !value.isAfter(rangeEnd);
}

DateTime _periodStartFor(BudgetPeriodType periodType, String periodKey) {
  final reference = DateTime.now();
  return switch (periodType) {
    BudgetPeriodType.monthly =>
      _parseYearMonthKey(periodKey) ??
          DateTime(reference.year, reference.month),
    BudgetPeriodType.weekly =>
      _parseDateKey(periodKey) ??
          reference.subtract(Duration(days: reference.weekday - 1)),
    BudgetPeriodType.custom =>
      _parseCustomRange(periodKey)?.start ??
          DateTime(reference.year, reference.month),
  };
}

DateTime _periodEndFor(BudgetPeriodType periodType, String periodKey) {
  final start = _periodStartFor(periodType, periodKey);
  return switch (periodType) {
    BudgetPeriodType.weekly => start.add(const Duration(days: 6)),
    BudgetPeriodType.custom => _parseCustomRange(periodKey)?.end ?? start,
    BudgetPeriodType.monthly => DateTime(start.year, start.month + 1, 0),
  };
}

String _budgetPeriodToDatabaseValue(BudgetPeriodType type) {
  return switch (type) {
    BudgetPeriodType.monthly => 'monthly',
    BudgetPeriodType.weekly => 'weekly',
    BudgetPeriodType.custom => 'custom',
  };
}

bool _sameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime? _parseYearMonthKey(String? key) {
  final parts = key?.split('-') ?? const <String>[];
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return null;
  return DateTime(year, month);
}

DateTime? _parseDateKey(String? key) {
  final parts = key?.split('-') ?? const <String>[];
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

({DateTime start, DateTime end})? _parseCustomRange(String? key) {
  final parts = key?.split('_') ?? const <String>[];
  if (parts.length != 2) return null;
  final start = _parseDateKey(parts[0]);
  final end = _parseDateKey(parts[1]);
  if (start == null || end == null) return null;
  return (start: start, end: end);
}
