import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_records.dart';
import '../../profile/application/locale_controller.dart';
import '../../transactions/domain/spend_categories.dart';
import '../data/category_service.dart';
import '../domain/category_display_labels.dart';
import '../domain/category_normalization.dart';

final class CategoryReadModel extends ChangeNotifier {
  CategoryReadModel({
    required CategoryService categoryService,
    LocaleController? localeController,
  }) : _categoryService = categoryService,
       _localeController = localeController {
    _localeController?.addListener(_onLocaleChanged);
  }

  final CategoryService _categoryService;
  final LocaleController? _localeController;
  StreamSubscription<List<CategoryRecord>>? _subscription;
  List<CategoryRecord> _categories = const [];

  List<CategoryRecord> get categories => List.unmodifiable(_categories);

  String get _localeTag => _localeController?.localeTag ?? 'en';

  List<String> get customCategories {
    final builtIns = {
      for (final category in kSelectableSpendCategories)
        normalizedCategoryKey(category),
    };
    final names = <String>[];
    final seen = <String>{};
    for (final category in _categories) {
      final name = category.name.trim();
      final key = categoryRecordKey(
        name: name,
        normalizedName: category.normalizedName,
      );
      if (name.isEmpty ||
          category.hidden ||
          isUnresolvedCategoryLabel(name) ||
          builtIns.contains(key) ||
          seen.contains(key)) {
        continue;
      }
      seen.add(key);
      names.add(name);
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(names);
  }

  Map<String, String> get categoryDisplayRenames =>
      CategoryLabelResolver.displayRenamesForLocaleTag(_localeTag);

  Set<String> get categoriesHiddenFromPicker {
    final hidden = <String>{};
    for (final category in _categories) {
      if (!category.hidden) continue;
      final key = categoryRecordKey(
        name: category.name,
        normalizedName: category.normalizedName,
      );
      if (key.isNotEmpty) hidden.add(key);
    }
    return Set.unmodifiable(hidden);
  }

  List<String> get allowedCategoryPickerLabels => categoryPickerCanonicals(
    customCategories: customCategories,
    hiddenLower: categoriesHiddenFromPicker,
  );

  String displayLabelForCategory(CategoryRecord category) {
    final normalized = category.normalizedName?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return CategoryLabelResolver.resolve(
        normalizedName: normalized,
        localeTag: _localeTag,
        fallbackName: category.name,
      );
    }
    return CategoryLabelResolver.resolveFromCanonicalName(
      canonicalName: category.name,
      localeTag: _localeTag,
    );
  }

  Future<void> refresh() async {
    _setCategories(await _categoryService.fetchCategories());
  }

  void applyRemoteCategories(Object? rows) {
    if (rows is! Iterable) return;
    _setCategories([
      for (final row in rows)
        if (row is CategoryRecord) row,
    ]);
  }

  void startWatching({required void Function() onChanged}) {
    if (_subscription != null) return;
    _subscription = _categoryService.watchCategories().listen((categories) {
      _setCategories(categories);
      onChanged();
    });
  }

  void stopWatching() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _setCategories(const []);
  }

  CategoryRecord? categoryById(String? id) {
    final key = id?.trim();
    if (key == null || key.isEmpty) return null;
    for (final category in _categories) {
      if (category.id == key) return category;
    }
    return null;
  }

  CategoryRecord? categoryByName(String name) {
    final key = normalizedCategoryKey(name);
    if (key.isEmpty) return null;
    for (final category in _categories) {
      if (categoryRecordKey(
            name: category.name,
            normalizedName: category.normalizedName,
          ) ==
          key) {
        return category;
      }
    }
    return null;
  }

  String? categoryNameForId(String? id) {
    final category = categoryById(id);
    if (category == null) return null;
    return displayLabelForCategory(category);
  }

  Future<CategoryRecord> ensureExpenseCategory(String name) async {
    final normalized = normalizeCategoryName(name);
    if (normalized == null) {
      throw const FormatException('Invalid category name.');
    }
    final existing = categoryByName(normalized.displayName);
    if (existing != null) return existing;
    final created = await _categoryService.createCategory(
      name: normalized.displayName,
      type: isIncomeCategoryLabel(normalized.displayName)
          ? 'income'
          : 'expense',
    );
    _setCategories([..._categories, created]);
    return created;
  }

  void _onLocaleChanged() {
    notifyListeners();
  }

  void _setCategories(List<CategoryRecord> categories) {
    _categories = List.unmodifiable(categories);
    notifyListeners();
  }

  @override
  void dispose() {
    _localeController?.removeListener(_onLocaleChanged);
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
