import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
