import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clarity/rex/memory/data/memory_labels.dart';

typedef ActionResultMessageFormatter =
    String Function(String action, List<Map<String, dynamic>> result);

final actionResultMessageFormatterProvider =
    Provider<ActionResultMessageFormatter>(
  (ref) => throw UnimplementedError(
    'actionResultMessageFormatterProvider must be overridden in ClarityApp.',
  ),
);

String actionResultMessage(
  AppLocalizations l10n,
  String action,
  List<Map<String, dynamic>> result,
) {
  final label = action.memoryRecordLabel;
  if (result.isEmpty) {
    // Applied rows come back from every control action, so an empty result
    // means the filter matched nothing — saying "done" would be a false claim.
    return l10n.chatActionMatchedNothing(label);
  }
  if (result.length == 1) {
    final merchant = result.single['merchant'];
    final description = result.single['description'];
    final name = result.single['name'];
    final subject = (merchant ?? description ?? name)?.toString().trim();
    if (subject != null && subject.isNotEmpty) {
      return l10n.chatActionDoneForSubject(label, subject);
    }
  }
  if (result.length == 1) {
    return l10n.chatActionDoneMultipleOne(label);
  }
  return l10n.chatActionDoneMultiple(label, result.length);
}
