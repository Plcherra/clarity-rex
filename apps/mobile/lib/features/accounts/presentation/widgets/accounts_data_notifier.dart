import 'package:flutter/foundation.dart';

import '../../../../app/ui_dependencies.dart';

class AccountsDataNotifier extends ChangeNotifier {
  List<AccountOverviewItem>? _data;
  Object? _error;
  var _loading = false;

  List<AccountOverviewItem>? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  void setLoading() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void setData(List<AccountOverviewItem> data) {
    _data = data;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void setError(Object error) {
    _error = error;
    _loading = false;
    notifyListeners();
  }
}
