part of 'category_management_sheet.dart';

bool _isManageableCategory(CategoryRecord category) {
  if (category.type != 'expense') return false;
  if (isUnresolvedCategoryLabel(category.name) ||
      isIgnoredCategoryLabel(category.name) ||
      isIncomeCategoryLabel(category.name)) {
    return false;
  }
  return true;
}

String _merchantRuleTitle(MerchantCategoryRule rule) {
  final display = rule.merchantDisplay?.trim();
  if (display != null && display.isNotEmpty) return display;
  return rule.merchantKey;
}
