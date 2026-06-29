import '../../../../l10n/app_localizations.dart';

enum MemoryQuickFilter {
  saved,
  people,
  preferences;

  String label(AppLocalizations l10n) {
    switch (this) {
      case MemoryQuickFilter.saved:
        return l10n.commonAll;
      case MemoryQuickFilter.people:
        return l10n.commonPeople;
      case MemoryQuickFilter.preferences:
        return l10n.commonPreferences;
    }
  }
}
