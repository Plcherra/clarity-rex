part of 'csv_parser.dart';

String dateCellParsingRule(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 'empty';

  if (DateTime.tryParse(s) != null) {
    return 'DateTime.tryParse (ISO-style full string)';
  }

  final slash = RegExp(
    r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$',
  ).firstMatch(s);
  if (slash != null) {
    final a = int.parse(slash.group(1)!);
    final b = int.parse(slash.group(2)!);
    if (a > 12) {
      return 'slash/dot/dash: first>12 => day=$a month=$b (leading part is day)';
    }
    if (b > 12) {
      return 'slash/dot/dash: second>12 => month=$a day=$b (US month/day)';
    }
    return 'slash/dot/dash: both<=12 => month=$a day=$b (US MM/DD/YYYY)';
  }

  final ymd = RegExp(r'^(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})$').firstMatch(s);
  if (ymd != null) {
    return 'yyyy-mm-dd order';
  }
  return 'no matching date pattern';
}

/// Parses CSV text into [Transaction] rows using flexible header matching.
///
/// Column detection is case-insensitive substring match on headers.
/// Supports a single signed [amount] column, or paired [debit]/[credit]

double? parseMoney(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  var neg = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    neg = true;
    s = s.substring(1, s.length - 1).trim();
  }
  if (s.endsWith('-')) {
    neg = true;
    s = s.substring(0, s.length - 1).trim();
  }
  if (s.startsWith('+')) {
    s = s.substring(1).trim();
  }

  s = s.replaceAll(RegExp(r'[\s$€£¥₹]'), '');

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (lastComma >= 0 && lastDot < 0) {
    final parts = s.split(',');
    if (parts.length == 2 &&
        parts[1].length <= 2 &&
        RegExp(r'^\d+$').hasMatch(parts[1])) {
      s = '${parts[0]}.${parts[1]}';
    } else {
      s = s.replaceAll(',', '');
    }
  }

  final v = double.tryParse(s);
  if (v == null) return null;
  return neg ? -v : v;
}

/// Returns date at local noon to reduce DST issues when comparing calendar months.
DateTime? _parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final iso = DateTime.tryParse(s);
  if (iso != null) {
    return DateTime(iso.year, iso.month, iso.day, 12);
  }

  // Slash, hyphen, or dot separators (e.g. 01/02/2025, 16.04.2026, 04-15-2026).
  // American exports: ambiguous pairs use MM/DD/YYYY (month first).
  final m = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$').firstMatch(s);
  if (m != null) {
    var a = int.parse(m.group(1)!);
    var b = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    int day;
    int month;
    if (a > 12) {
      // Cannot be a US month (e.g. 25/12/2025, 16.04.2026).
      day = a;
      month = b;
    } else if (b > 12) {
      // Second part is the day (e.g. 03/25/2025).
      month = a;
      day = b;
    } else {
      // Ambiguous: US MM/DD/YYYY.
      month = a;
      day = b;
    }
    return DateTime(y, month, day, 12);
  }

  final mIso = RegExp(r'^(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})$').firstMatch(s);
  if (mIso != null) {
    final y = int.parse(mIso.group(1)!);
    final mo = int.parse(mIso.group(2)!);
    final d = int.parse(mIso.group(3)!);
    return DateTime(y, mo, d, 12);
  }

  return null;
}
