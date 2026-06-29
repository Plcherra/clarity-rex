import 'package:flutter/material.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final label = action.replaceAll('_', ' ');
  if (result.isEmpty) {
    return l10n.chatActionDoneSingle(label);
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
