import 'dart:math' show min;

import 'package:csv/csv.dart';

import '../../../core/models/models.dart';

part 'csv_parser_models.dart';
part 'csv_parser_values.dart';
part 'csv_parser_layout.dart';

ParseResult parseBankCsv(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('File is empty');
  }

  final rows = _parseRows(trimmed);
  if (rows.isEmpty || rows.first.isEmpty) {
    throw const FormatException('No rows found');
  }

  final layout = _detectTableLayout(rows);
  if (layout == null) {
    throw const FormatException(
      'Could not find required columns (need date and either amount or debit/credit). '
      'Tip: include a row with headers such as Date + Amount, or Data + Valor, or Debit/Credit.',
    );
  }

  final headerRowIndex = layout.headerRowIndex;
  final headers = layout.headers;
  final col = layout.columns;

  final txs = <Transaction>[];
  String? firstParsedDateRaw;
  String? lastParsedDateRaw;
  for (var r = headerRowIndex + 1; r < rows.length; r++) {
    final row = rows[r];
    if (_isBlankRow(row)) continue;

    final cells = _padRow(row, headers.length);
    final dateStr = col.date != null ? cells[col.date!].toString().trim() : '';
    if (dateStr.isEmpty) continue;

    final date = _parseDate(dateStr);
    if (date == null) {
      // Skip lines that look like repeated headers or junk.
      if (_looksLikeHeader(cells)) continue;
      continue;
    }

    final desc = col.description != null
        ? cells[col.description!].toString().trim()
        : '';
    final category = col.category != null
        ? cells[col.category!].toString().trim()
        : null;
    final categoryOrNull = (category == null || category.isEmpty)
        ? null
        : category;

    double? amount;
    if (col.amount != null) {
      final rawAmount = parseMoney(cells[col.amount!].toString());
      if (rawAmount == null) {
        amount = null;
      } else {
        final typeStr = col.transactionType != null
            ? cells[col.transactionType!].toString().trim()
            : '';
        final t = typeStr.toLowerCase();
        if (t == 'debit') {
          amount = -rawAmount.abs();
        } else if (t == 'credit') {
          amount = rawAmount.abs();
        } else {
          amount = rawAmount;
        }
      }
    } else if (col.debit != null || col.credit != null) {
      final d = col.debit != null
          ? parseMoney(cells[col.debit!].toString())
          : 0.0;
      final c = col.credit != null
          ? parseMoney(cells[col.credit!].toString())
          : 0.0;
      final debit = d ?? 0.0;
      final credit = c ?? 0.0;
      amount = credit - debit;
    }

    if (amount == null || amount.isNaN) continue;

    final balStr = col.balance != null ? cells[col.balance!].toString() : '';
    final balanceAfter = parseMoney(balStr);

    firstParsedDateRaw ??= dateStr;
    lastParsedDateRaw = dateStr;

    txs.add(
      Transaction(
        date: date,
        description: desc.isEmpty ? 'Transaction' : desc,
        amount: amount,
        accountId: '',
        category: categoryOrNull,
        balanceAfter: balanceAfter,
        categoryLabel: null,
      ),
    );
  }

  if (txs.isEmpty) {
    throw const FormatException('No valid transactions found');
  }

  double? totalBalance;
  if (col.balance != null) {
    for (var i = txs.length - 1; i >= 0; i--) {
      final b = txs[i].balanceAfter;
      if (b != null && !b.isNaN) {
        totalBalance = b;
        break;
      }
    }
  }

  final dateIdx = col.date;
  final amtIdx = col.amount;
  final balIdx = col.balance;
  final diagnostics = CsvParseDiagnostics(
    layoutInferred: layout.layoutInferred,
    headerRowIndex: headerRowIndex,
    dateColumnIndex: dateIdx,
    dateColumnHeader: dateIdx != null && dateIdx < headers.length
        ? headers[dateIdx]
        : null,
    amountColumnIndex: amtIdx,
    amountColumnHeader: amtIdx != null && amtIdx < headers.length
        ? headers[amtIdx]
        : null,
    balanceColumnIndex: balIdx,
    balanceColumnHeader: balIdx != null && balIdx < headers.length
        ? headers[balIdx]
        : null,
    ambiguousSlashPolicy:
        'US-style dates: when month and day are ambiguous (both ≤12), '
        '_parseDate uses MM/DD/YYYY (month first). If first part >12 it is '
        'the day; if second part >12 the first is the month.',
    firstParsedDateRawCell: firstParsedDateRaw,
    lastParsedDateRawCell: lastParsedDateRaw,
    firstCellParsingRule: firstParsedDateRaw != null
        ? dateCellParsingRule(firstParsedDateRaw)
        : null,
    lastCellParsingRule: lastParsedDateRaw != null
        ? dateCellParsingRule(lastParsedDateRaw)
        : null,
  );

  return ParseResult(
    transactions: txs,
    totalBalance: totalBalance,
    diagnostics: diagnostics,
  );
}
