part of 'csv_parser.dart';

/// Result of parsing a bank-export style CSV.
class ParseResult {
  const ParseResult({
    required this.transactions,
    this.totalBalance,
    this.diagnostics,
  });

  final List<Transaction> transactions;

  /// From balance column (last row file order) or running sum when inferable.
  final double? totalBalance;

  /// Column detection and raw date cells (for debugging imports).
  final CsvParseDiagnostics? diagnostics;
}

/// Column picks and how date strings are interpreted (see [dateCellParsingRule]).
class CsvParseDiagnostics {
  const CsvParseDiagnostics({
    required this.layoutInferred,
    required this.headerRowIndex,
    this.dateColumnIndex,
    this.dateColumnHeader,
    this.amountColumnIndex,
    this.amountColumnHeader,
    this.balanceColumnIndex,
    this.balanceColumnHeader,
    required this.ambiguousSlashPolicy,
    this.firstParsedDateRawCell,
    this.lastParsedDateRawCell,
    this.firstCellParsingRule,
    this.lastCellParsingRule,
  });

  /// True when headers did not match and [_inferTableLayout] chose columns.
  final bool layoutInferred;

  /// 0-based row index of the header row used for column indices.
  final int headerRowIndex;

  final int? dateColumnIndex;
  final String? dateColumnHeader;
  final int? amountColumnIndex;
  final String? amountColumnHeader;
  final int? balanceColumnIndex;
  final String? balanceColumnHeader;

  /// How ambiguous `MM/DD` numeric dates are resolved (US bank exports).
  final String ambiguousSlashPolicy;

  final String? firstParsedDateRawCell;
  final String? lastParsedDateRawCell;
  final String? firstCellParsingRule;
  final String? lastCellParsingRule;
}
