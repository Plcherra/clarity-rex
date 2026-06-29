# ARB & Localization Conventions

English (`app_en.arb`) is the source of truth for all user-facing copy until a language phase (e.g. L1 Spanish) translates other ARB files.

## Key naming

- Pattern: `featureScreen_element` or shared `common*` for reused strings.
- Examples: `accountsScreen_connectBank`, `chatPageSendFailed`, `commonCancel`.
- Parameterized strings use ARB `@` metadata with typed placeholders.

## Where strings live

| Layer | Pattern |
|-------|---------|
| **Widgets** | `context.l10n.keyName` via `app_l10n.dart` |
| **Services / controllers** | Injected `AppLocalizations Function()` or `bindLocalizations(AppLocalizations)` |
| **Riverpod providers** | Override in `ClarityApp` `ProviderScope`; watch `localeController` for locale changes |
| **Locale lookup** | `lookupForLocale(locale)` from `app_localizations_lookup.dart` — never hardcode `Locale('en')` in production |

## Service injection

1. Constructor accepts optional `AppLocalizations Function()? l10n`.
2. If unset, throw `StateError` on first use (or require `bindLocalizations` from a host widget).
3. Host widgets call `bindLocalizations(context.l10n)` in `didChangeDependencies` so locale switches refresh messages.
4. Unit tests use `lookupEnglishLocalizationsForTests()` or explicit test factories (e.g. `importJobStatusServiceForTests()`).

## Composition root (`app.dart`)

- `localeControllerProvider` overridden with app-level controller.
- `actionResultMessageFormatterProvider`, `chatApiProvider`, voice APIs wired with `AppLocale.rexLocaleTag(localeController)`.
- Formatters use `lookupForLocale(ref.watch(localeControllerProvider).locale)`.

## Catalog vs gen-l10n

- `ClarityLocaleCatalog` — which locales exist, which are enabled in Profile, fallback rules.
- `app_en.arb` / `app_es.arb` — UI strings; `app_es.arb` mirrors English until L1.
- Rex APIs receive full BCP-47 tags from `LocaleController.localeTag`.

## Do not

- Hardcode English in services, snackbars, or error helpers.
- Use `lookupAppLocalizations(const Locale('en'))` in production code.
- Add topic-specific recall or UI patches in l10n — keep keys generic and reusable.
