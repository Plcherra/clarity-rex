import 'package:clarity/features/categories/domain/category_display_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryLabelResolver', () {
    test('returns Spanish labels when locale tag is es', () {
      expect(
        CategoryLabelResolver.resolve(
          normalizedName: 'food drink',
          localeTag: 'es',
        ),
        'Comida y bebida',
      );
      expect(
        CategoryLabelResolver.resolve(
          normalizedName: 'transportation',
          localeTag: 'es-MX',
        ),
        'Transporte',
      );
    });

    test('falls back to English for unsupported locales', () {
      expect(
        CategoryLabelResolver.resolve(
          normalizedName: 'food drink',
          localeTag: 'fr',
        ),
        'Food & Drink',
      );
    });

    test('falls back to canonical name for unknown categories', () {
      expect(
        CategoryLabelResolver.resolve(
          normalizedName: 'custom category',
          localeTag: 'es',
          fallbackName: 'Custom Category',
        ),
        'Custom Category',
      );
    });

    test('produces Spanish display renames for es locale', () {
      final renames = CategoryLabelResolver.displayRenamesForLocaleTag('es');
      expect(renames['food & drink'], 'Comida y bebida');
      expect(renames['transportation'], 'Transporte');
    });

    test('resolveFromCanonicalName normalizes punctuation', () {
      expect(
        CategoryLabelResolver.resolveFromCanonicalName(
          canonicalName: 'Food & Drink',
          localeTag: 'es',
        ),
        'Comida y bebida',
      );
    });

    test('maps localized display labels back to English canonical names', () {
      final renames = CategoryLabelResolver.displayRenamesForLocaleTag('es');
      expect(
        CategoryLabelResolver.canonicalEnglishLabelFromDisplay(
          displayLabel: 'Supermercado',
          renamesLowerToDisplay: renames,
        ),
        'Grocery / Supermarket',
      );
    });
  });
}
