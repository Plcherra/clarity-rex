import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_dialogs.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_flat_sheet.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_structured_sheet.dart';

export 'package:clarity/rex/memory/presentation/widgets/memory_edit_dialogs.dart'
    show MemoryEditResult, StructuredEditResult;

Future<MemoryEditResult?> showMemoryEditSheet(
  BuildContext context, {
  required MemoryItem memory,
}) {
  return showFlatMemoryEditSheet(context, memory: memory);
}

Future<StructuredEditResult?> showStructuredEditSheet(
  BuildContext context, {
  required String title,
  required String typeLabel,
  required String primaryLabel,
  required String primaryValue,
  required String detailLabel,
  required String? detailValue,
  required String importanceLabel,
  required int importance,
  required String status,
  required bool active,
  required DateTime? updatedAt,
  required DateTime? createdAt,
  String? extraLabel,
  String? extraValue,
}) {
  return showStructuredMemoryEditSheet(
    context,
    title: title,
    typeLabel: typeLabel,
    primaryLabel: primaryLabel,
    primaryValue: primaryValue,
    detailLabel: detailLabel,
    detailValue: detailValue,
    importanceLabel: importanceLabel,
    importance: importance,
    status: status,
    active: active,
    updatedAt: updatedAt,
    createdAt: createdAt,
    extraLabel: extraLabel,
    extraValue: extraValue,
  );
}
