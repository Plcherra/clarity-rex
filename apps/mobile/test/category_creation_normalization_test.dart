import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes case, spacing, and punctuation for display and dedupe', () {
    final first = normalizeCategoryName(' pet-care!! ');
    final second = normalizeCategoryName('PET   care');

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.displayName, 'Pet Care');
    expect(first.normalizedName, 'pet care');
    expect(second!.displayName, 'Pet Care');
    expect(second.normalizedName, first.normalizedName);
  });

  test('normalizes connector words out of category dedupe keys', () {
    final ampersand = normalizeCategoryName('Food & Drink');
    final plain = normalizeCategoryName('Food Drink');
    final spaced = normalizeCategoryName('Food   Drink');

    expect(ampersand, isNotNull);
    expect(plain, isNotNull);
    expect(spaced, isNotNull);
    expect(ampersand!.normalizedName, 'food drink');
    expect(plain!.normalizedName, ampersand.normalizedName);
    expect(spaced!.normalizedName, ampersand.normalizedName);
  });

  test('rejects unsafe category suggestions', () {
    expect(normalizeCategoryName('https://example.com'), isNull);
    expect(normalizeCategoryName('person@example.com'), isNull);
    expect(normalizeCategoryName('<script>'), isNull);
    expect(normalizeCategoryName('!!!'), isNull);
  });

  test('rejects one-letter and non-meaningful category suggestions', () {
    expect(normalizeCategoryName('C'), isNull);
    expect(normalizeCategoryName('x'), isNull);
    expect(normalizeCategoryName('--a--'), isNull);
    expect(normalizeCategoryName('Gas'), isNotNull);
  });

  test('keeps Unknown as the stable fallback category', () {
    final unknown = normalizeCategoryName(kUnknownCategoryName);

    expect(unknown, isNotNull);
    expect(unknown!.displayName, kUnknownCategoryName);
    expect(unknown.normalizedName, 'unknown');
  });
}
