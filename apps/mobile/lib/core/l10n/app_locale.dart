import 'package:flutter/widgets.dart';

import '../../features/profile/application/locale_controller.dart';

export 'clarity_locale_catalog.dart'
    show ClarityLocaleCatalog, ClarityLocaleSpec, claritySupportedLocales;
export 'app_localizations_lookup.dart'
    show lookupForLocale, lookupForLocaleTag, lookupEnglishLocalizationsForTests;
export '../../features/profile/application/locale_controller.dart'
    show LocaleController, localeControllerProvider;
/// Single source of truth for Clarity UI and Rex locale.
///
/// UI ([MaterialApp]), formatting, category labels, chat, and voice must read
/// from [LocaleController] — never pick language independently.
abstract final class AppLocale {
  /// Device locale from the platform (equivalent to `Platform.localeName`).
  static Locale readDeviceLocale() => LocaleController.readDeviceLocale();

  /// Language/locale tag sent to Rex chat and voice APIs.
  static String rexLocaleTag(LocaleController controller) => controller.localeTag;
}
