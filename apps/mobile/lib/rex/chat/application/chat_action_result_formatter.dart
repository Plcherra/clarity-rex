String actionResultMessage(String action, List<Map<String, dynamic>> result) {
  final label = action.replaceAll('_', ' ');
  if (result.isEmpty) {
    return 'Done. I applied the $label change.';
  }
  if (result.length == 1) {
    final merchant = result.single['merchant'];
    final description = result.single['description'];
    final name = result.single['name'];
    final subject = (merchant ?? description ?? name)?.toString().trim();
    if (subject != null && subject.isNotEmpty) {
      return 'Done. I applied the $label change for $subject.';
    }
  }
  final plural = result.length == 1 ? '' : 's';
  return 'Done. I applied the $label change to ${result.length} record$plural.';
}
