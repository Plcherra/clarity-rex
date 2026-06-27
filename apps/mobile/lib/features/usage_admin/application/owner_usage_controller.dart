import 'package:flutter/foundation.dart';

import 'package:clarity/features/usage_admin/data/usage_admin_api.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';

final class OwnerUsageController extends ChangeNotifier {
  OwnerUsageController({UsageAdminApi? api}) : _api = api ?? UsageAdminApi();

  final UsageAdminApi _api;

  var isLoading = false;
  String? errorMessage;
  OwnerPlatformSummary? summary;
  List<OwnerUserUsage> users = const [];

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchPlatformSummary(),
        _api.fetchAllUsers(),
      ]);
      summary = results[0] as OwnerPlatformSummary;
      users = results[1] as List<OwnerUserUsage>;
      users.sort(
        (a, b) => b.monthEstimatedCostCents.compareTo(a.monthEstimatedCostCents),
      );
      isLoading = false;
      notifyListeners();
    } on Object catch (_) {
      isLoading = false;
      errorMessage = 'Could not load owner usage right now.';
      notifyListeners();
    }
  }
}

final class OwnerUserDetailController extends ChangeNotifier {
  OwnerUserDetailController({
    required this.user,
    UsageAdminApi? api,
  }) : _api = api ?? UsageAdminApi();

  final OwnerUserUsage user;
  final UsageAdminApi _api;

  var isLoading = false;
  String? errorMessage;
  OwnerUserDailyUsage? dailyUsage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      dailyUsage = await _api.fetchUserDaily(user.userId);
      isLoading = false;
      notifyListeners();
    } on Object catch (_) {
      isLoading = false;
      errorMessage = 'Could not load user usage history.';
      notifyListeners();
    }
  }
}

final class OwnerAccessController extends ChangeNotifier {
  OwnerAccessController({UsageAdminApi? api}) : _api = api ?? UsageAdminApi();

  final UsageAdminApi _api;

  var isLoading = true;
  var isOwner = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      isOwner = await _api.fetchOwnerAccess();
    } on Object catch (_) {
      isOwner = false;
    }
    isLoading = false;
    notifyListeners();
  }
}
