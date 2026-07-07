enum UsageAdminPeriodKind { all, year, month, day }

final class UsageAdminFilter {
  const UsageAdminFilter({
    required this.period,
    required this.year,
    required this.month,
    required this.day,
  });

  factory UsageAdminFilter.defaults() {
    final now = DateTime.now();
    return UsageAdminFilter(
      period: UsageAdminPeriodKind.all,
      year: now.year,
      month: now.month,
      day: DateTime(now.year, now.month, now.day),
    );
  }

  final UsageAdminPeriodKind period;
  final int year;
  final int month;
  final DateTime day;

  UsageAdminFilter copyWith({
    UsageAdminPeriodKind? period,
    int? year,
    int? month,
    DateTime? day,
  }) {
    return UsageAdminFilter(
      period: period ?? this.period,
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
    );
  }

  Map<String, String> toQuery() {
    final query = <String, String>{'period': period.name};
    switch (period) {
      case UsageAdminPeriodKind.all:
        return query;
      case UsageAdminPeriodKind.year:
        query['year'] = year.toString();
        return query;
      case UsageAdminPeriodKind.month:
        query['year'] = year.toString();
        query['month'] = month.toString();
        return query;
      case UsageAdminPeriodKind.day:
        query['day'] = _dateString(day);
        return query;
    }
  }

  DateTime get rangeStart {
    switch (period) {
      case UsageAdminPeriodKind.all:
        return DateTime(2026, 1, 1);
      case UsageAdminPeriodKind.year:
        return DateTime(year, 1, 1);
      case UsageAdminPeriodKind.month:
        return DateTime(year, month, 1);
      case UsageAdminPeriodKind.day:
        return DateTime(day.year, day.month, day.day);
    }
  }

  DateTime get rangeEnd {
    switch (period) {
      case UsageAdminPeriodKind.all:
      case UsageAdminPeriodKind.year:
      case UsageAdminPeriodKind.month:
        return DateTime.now();
      case UsageAdminPeriodKind.day:
        return DateTime(day.year, day.month, day.day);
    }
  }

  static String _dateString(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
