part of 'csv_parser.dart';

bool _looksLikeHeader(List<dynamic> cells) {
  final joined = _foldHeader(cells.map((c) => c.toString()).join(' '));
  final hasDateLike =
      joined.contains('date') ||
      joined.contains('data') ||
      joined.contains('fecha');
  final hasMoneyLike =
      joined.contains('amount') ||
      joined.contains('balance') ||
      joined.contains('valor') ||
      joined.contains('montante') ||
      joined.contains('importe') ||
      joined.contains('debit') ||
      joined.contains('credit');
  return hasDateLike && hasMoneyLike;
}

bool _isBlankRow(List<dynamic> row) {
  return row.every((c) => c == null || c.toString().trim().isEmpty);
}

List<dynamic> _padRow(List<dynamic> row, int len) {
  if (row.length >= len) return row;
  return [...row, ...List.filled(len - row.length, '')];
}

List<String> _normalizeHeaderRow(List<dynamic> raw) {
  return raw
      .map((c) => c.toString().trim().replaceFirst(RegExp(r'^\ufeff'), ''))
      .toList();
}

/// Lowercase + strip common Latin accents so "Débito" matches needle "debito".
String _foldHeader(String raw) {
  var s = raw.toLowerCase().trim();
  const folding = <List<String>>[
    ['á', 'a'],
    ['à', 'a'],
    ['â', 'a'],
    ['ã', 'a'],
    ['ä', 'a'],
    ['å', 'a'],
    ['é', 'e'],
    ['è', 'e'],
    ['ê', 'e'],
    ['ë', 'e'],
    ['í', 'i'],
    ['ì', 'i'],
    ['î', 'i'],
    ['ï', 'i'],
    ['ó', 'o'],
    ['ò', 'o'],
    ['ô', 'o'],
    ['õ', 'o'],
    ['ö', 'o'],
    ['ú', 'u'],
    ['ù', 'u'],
    ['û', 'u'],
    ['ü', 'u'],
    ['ý', 'y'],
    ['ÿ', 'y'],
    ['ñ', 'n'],
    ['ç', 'c'],
    ['ł', 'l'],
    ['ń', 'n'],
    ['ś', 's'],
    ['ź', 'z'],
    ['ż', 'z'],
    ['ą', 'a'],
    ['ę', 'e'],
    ['ć', 'c'],
  ];
  for (final p in folding) {
    s = s.replaceAll(p[0], p[1]);
  }
  return s;
}

int? _findExactHeaderIndex(List<String> headers, Set<String> foldedLabels) {
  for (var i = 0; i < headers.length; i++) {
    if (foldedLabels.contains(_foldHeader(headers[i]))) return i;
  }
  return null;
}

class _TableLayout {
  const _TableLayout({
    required this.headerRowIndex,
    required this.headers,
    required this.columns,
    this.layoutInferred = false,
  });

  final int headerRowIndex;
  final List<String> headers;
  final _ColumnMap columns;

  /// True when [_inferTableLayout] produced this layout (no header match).
  final bool layoutInferred;
}

_TableLayout? _detectTableLayout(List<List<dynamic>> rows) {
  final maxHeaderScan = rows.length.clamp(0, 14);
  for (var hi = 0; hi < maxHeaderScan; hi++) {
    final headers = _normalizeHeaderRow(rows[hi]);
    if (headers.isEmpty || headers.every((e) => e.isEmpty)) continue;
    final col = _ColumnMap.fromHeaders(headers);
    if (col.canBuildTransactions) {
      return _TableLayout(
        headerRowIndex: hi,
        headers: headers,
        columns: col,
        layoutInferred: false,
      );
    }
  }
  return _inferTableLayout(rows);
}

/// Guesses date + amount columns from cell contents when headers are unknown.
_TableLayout? _inferTableLayout(List<List<dynamic>> rows) {
  _TableLayout? best;
  var bestScore = -1.0;

  for (var hi = 0; hi < min(10, rows.length - 1); hi++) {
    final headers = _normalizeHeaderRow(rows[hi]);
    final nCols = headers.length;
    if (nCols < 2) continue;

    final samples = <List<String>>[];
    for (var r = hi + 1; r < rows.length && samples.length < 24; r++) {
      if (_isBlankRow(rows[r])) continue;
      samples.add(
        _padRow(rows[r], nCols).map((e) => e.toString().trim()).toList(),
      );
    }
    if (samples.isEmpty) continue;

    for (var dc = 0; dc < nCols; dc++) {
      final dHits = samples
          .where((s) => dc < s.length && _parseDate(s[dc]) != null)
          .length;
      final dScore = dHits / samples.length;
      if (dScore < 0.42) continue;

      for (var mc = 0; mc < nCols; mc++) {
        if (mc == dc) continue;
        final mHits = samples.where((s) {
          if (mc >= s.length) return false;
          return parseMoney(s[mc]) != null;
        }).length;
        final mScore = mHits / samples.length;
        if (mScore < 0.32) continue;

        var neg = 0;
        var pos = 0;
        for (final s in samples) {
          if (mc >= s.length) continue;
          final v = parseMoney(s[mc]);
          if (v == null) continue;
          if (v < 0) neg++;
          if (v > 0) pos++;
        }
        final signedBonus = (neg > 0 && pos > 0) ? 0.15 : 0.0;
        final score = dScore * mScore + signedBonus;
        if (score <= bestScore) continue;
        bestScore = score;

        int? descCol;
        var bestLen = 0.0;
        for (var t = 0; t < nCols; t++) {
          if (t == dc || t == mc) continue;
          var len = 0.0;
          for (final s in samples) {
            if (t < s.length) len += s[t].length;
          }
          len /= samples.length;
          if (len > bestLen && len > 4) {
            bestLen = len;
            descCol = t;
          }
        }

        best = _TableLayout(
          headerRowIndex: hi,
          headers: headers,
          columns: _ColumnMap(date: dc, amount: mc, description: descCol),
          layoutInferred: true,
        );
      }
    }
  }
  return best;
}

List<List<dynamic>> _parseRows(String input) {
  final firstLine = input
      .split(RegExp(r'\r?\n'))
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final comma = RegExp(',').allMatches(firstLine).length;
  final semi = RegExp(';').allMatches(firstLine).length;
  final tab = RegExp(r'\t').allMatches(firstLine).length;
  String delim = ',';
  if (semi > comma && semi >= tab) delim = ';';
  if (tab > comma && tab > semi) delim = '\t';

  final converter = CsvDecoder(fieldDelimiter: delim, dynamicTyping: false);
  return converter.convert(
    input.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
  );
}

class _ColumnMap {
  _ColumnMap({
    this.date,
    this.amount,
    this.debit,
    this.credit,
    this.transactionType,
    this.description,
    this.category,
    this.balance,
  });

  factory _ColumnMap.fromHeaders(List<String> headers) {
    int? find(List<String> needles, {bool Function(String h)? extra}) {
      for (var i = 0; i < headers.length; i++) {
        final h = _foldHeader(headers[i]);
        if (extra != null && !extra(h)) continue;
        for (final n in needles) {
          if (h == n || h.contains(n)) return i;
        }
      }
      return null;
    }

    // More specific patterns first; [h] is accent-folded lowercase.
    var dateIdx = find([
      'transaction date',
      'posting date',
      'posted date',
      'date posted',
      'post date',
      'trans date',
      'tran date',
      'settlement date',
      'activity date',
      'value date',
      'effective date',
      'eff. date',
      'ledger date',
      'booking date',
      'purchase date',
      'buchungstag',
      'valutadatum',
      'valuta',
      'data valor',
      'data movimento',
      'data movimentacao',
      'data operacao',
      'data operación',
      'data transaccion',
      'data transação',
      'booked on',
      'booked',
      'posted',
      'fecha',
      'datum',
      'when',
      'timestamp',
      'date',
    ]);

    dateIdx ??= _findExactHeaderIndex(headers, {
      'data',
      'fecha',
      'datum',
      'day',
    });

    final balanceIdx = find(
      [
        'running balance',
        'closing balance',
        'ending balance',
        'saldo',
        'balance',
      ],
      extra: (h) {
        return !h.contains('available');
      },
    );

    final debitIdx = find([
      'paid out',
      'money out',
      'withdrawals',
      'withdrawal',
      'debits',
      'debito',
      'debit',
      'dr',
      'soll',
      'lastschrift',
      'abbuchung',
    ]);

    final creditIdx = find(
      [
        'paid in',
        'money in',
        'deposits',
        'deposit',
        'credito',
        'credits',
        'credit',
        'cr',
        'haben',
        'gutschrift',
      ],
      extra: (h) {
        if (h.contains('card') &&
            !h.contains('paid in') &&
            !h.contains('money in')) {
          return false;
        }
        return true;
      },
    );

    int? amountIdx;
    for (final candidate in [
      'transaction amount',
      'net amount',
      'montante',
      'importe',
      'importo',
      'betrag',
      'montant',
      'kwota',
      'amount',
      'value',
      'valor',
      'amt',
      'payment',
      'payments',
    ]) {
      final idx = find(
        [candidate],
        extra: (h) {
          if (h.contains('balance')) return false;
          if (h.contains('date')) return false;
          if (h.contains('subtotal')) return false;
          if (candidate == 'valor' &&
              h.contains('data') &&
              h.contains('valor')) {
            return false;
          }
          return true;
        },
      );
      if (idx != null && idx != balanceIdx) {
        amountIdx = idx;
        break;
      }
    }

    amountIdx ??= _findExactHeaderIndex(headers, {
      'valor',
      'montante',
      'importe',
      'importo',
      'betrag',
      'montant',
      'kwota',
      'amount',
    });

    final descIdx = find([
      'description',
      'details',
      'narrative',
      'memo',
      'payee',
      'merchant',
      'counter party',
      'counterparty',
      'name',
      'libelle',
      'descricao',
      'descripcion',
      'concepto',
      'motivo',
      'verwendungszweck',
      'buchungstext',
    ]);

    int? transactionTypeIdx = find([
      'transaction type',
      'tran type',
      'trans type',
      'transaction_type',
    ]);
    // Some Capital One exports use `Type` for Debit/Credit; only accept it when
    // the file also contains `Transaction Amount` (avoids confusing with category/type).
    transactionTypeIdx ??=
        (amountIdx != null &&
            _foldHeader(headers[amountIdx]).contains('transaction amount'))
        ? _findExactHeaderIndex(headers, {'type'})
        : null;

    int? catIdx = find(
      ['category', 'type', 'classification'],
      extra: (h) {
        // Avoid treating `Transaction Type` (Debit/Credit) as the category column.
        if (h.contains('transaction type')) return false;
        if (h.contains('transaction_type')) return false;
        return true;
      },
    );
    // If we still collided (rare), prefer `transactionType`.
    if (transactionTypeIdx != null && transactionTypeIdx == catIdx) {
      catIdx = null;
    }

    return _ColumnMap(
      date: dateIdx,
      amount: amountIdx,
      debit: debitIdx,
      credit: creditIdx,
      transactionType: transactionTypeIdx,
      description: descIdx,
      category: catIdx,
      balance: balanceIdx,
    );
  }

  final int? date;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? transactionType;
  final int? description;
  final int? category;
  final int? balance;

  bool get canBuildTransactions {
    if (date == null) return false;
    if (amount != null) return true;
    return debit != null || credit != null;
  }
}

/// Parses money strings with common currency symbols and decimal separators.
