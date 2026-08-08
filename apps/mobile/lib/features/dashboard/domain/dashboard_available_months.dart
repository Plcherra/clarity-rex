import '../../transactions/domain/bank_statement_monthly.dart';

/// Distinct `YYYY-MM` keys for the Overview month switcher, newest first.
///
/// Always includes the current calendar month so users can return to "now"
/// even when that month has no posted transactions yet.
List<String> dashboardAvailableYearMonths({
  required Iterable<DateTime> transactionDates,
  DateTime? now,
}) {
  final keys = <String>{};
  for (final date in transactionDates) {
    keys.add(yearMonthKey(date));
  }
  final referenceNow = now ?? DateTime.now();
  keys.add(yearMonthKey(referenceNow));
  final list = keys.toList(growable: false)
    ..sort((a, b) => b.compareTo(a));
  return list;
}

DateTime? parseDashboardYearMonth(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month, 1);
}
