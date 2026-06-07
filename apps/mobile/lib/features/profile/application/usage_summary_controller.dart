import 'package:flutter/foundation.dart';

import 'usage_summary_service.dart';

final class UsageSummaryController extends ChangeNotifier {
  UsageSummaryController({required UsageSummaryService usageSummaryService})
    : _usageSummaryService = usageSummaryService;

  final UsageSummaryService _usageSummaryService;

  VoiceUsageTotals totals = VoiceUsageTotals.empty();
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      totals = await _usageSummaryService.fetchVoiceUsageTotals();
    } on Object {
      errorMessage = 'Could not load usage right now.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
