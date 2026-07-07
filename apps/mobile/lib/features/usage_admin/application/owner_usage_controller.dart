import 'package:flutter/foundation.dart';

import 'package:clarity/features/usage_admin/data/usage_admin_filter.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_api.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';

final class OwnerUsageController extends ChangeNotifier {
  OwnerUsageController({UsageAdminApi? api}) : _api = api ?? UsageAdminApi();

  final UsageAdminApi _api;

  var isLoading = false;
  var loadFailed = false;
  UsageAdminFilter filter = UsageAdminFilter.defaults();
  OwnerPlatformSummary? summary;
  List<OwnerUserUsage> users = const [];

  Future<void> load() async {
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchPlatformSummary(filter),
        _api.fetchAllUsers(filter),
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
      loadFailed = true;
      notifyListeners();
    }
  }

  Future<void> setFilter(UsageAdminFilter next) async {
    filter = next;
    await load();
  }
}

final class OwnerUserDetailController extends ChangeNotifier {
  OwnerUserDetailController({
    required this.user,
    required this.filter,
    UsageAdminApi? api,
  }) : _api = api ?? UsageAdminApi();

  final OwnerUserUsage user;
  final UsageAdminFilter filter;
  final UsageAdminApi _api;

  var isLoading = false;
  var loadFailed = false;
  OwnerUserDailyUsage? dailyUsage;

  Future<void> load() async {
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    try {
      dailyUsage = await _api.fetchUserDaily(user.userId, filter: filter);
      isLoading = false;
      notifyListeners();
    } on Object catch (_) {
      isLoading = false;
      loadFailed = true;
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
