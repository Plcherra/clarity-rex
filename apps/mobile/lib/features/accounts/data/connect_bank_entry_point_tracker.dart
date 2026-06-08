import 'package:flutter/foundation.dart';

enum ConnectBankEntryAction { connectBank, importCsvInstead, addManualAccount }

void trackConnectBankEntryPoint({
  required String surface,
  required ConnectBankEntryAction action,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[Clarity][financial_setup_entry] '
    'surface=$surface action=${action.name}',
  );
}
