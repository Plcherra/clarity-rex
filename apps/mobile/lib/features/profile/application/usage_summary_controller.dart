import 'package:flutter/foundation.dart';

import 'usage_summary_service.dart';

final class UsageSummaryController extends ChangeNotifier {
  UsageSummaryController({required UsageSummaryService usageSummaryService})
    : _usageSummaryService = usageSummaryService;

  final UsageSummaryService _usageSummaryService;

  VoiceUsageTotals totals = VoiceUsageTotals.empty();
  bool isLoading = false;
  bool loadFailed = false;

  Future<void> load() async {
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    try {
      totals = await _usageSummaryService.fetchVoiceUsageTotals();
    } on Object {
      loadFailed = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
