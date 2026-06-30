import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_tile_shell.dart';

class EntityMemoryTile extends StatelessWidget {
  const EntityMemoryTile({
    required this.entity,
    required this.onEdit,
    required this.onDeactivate,
    this.eventPreviews = const [],
    super.key,
  });

  final EntityMemoryItem entity;
  final List<EntityEventItem> eventPreviews;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final supplementalLabels = <String>[
      if (entity.location != null) entity.location!,
      if (entity.notes != null) entity.notes!,
      ...entityEventPreviewLabels(l10n, eventPreviews),
    ];

    return StructuredMemoryTile(
      icon: entity.isPlace ? Icons.place_outlined : Icons.category_outlined,
      active: entity.active,
      title: entity.displayName,
      subtitle: entity.summary,
      typeLabel: entityTypeLabel(l10n, entity.entityType),
      importance: entity.importance,
      updatedAt: entity.updatedAt,
      createdAt: entity.createdAt,
      supplementalLabels: supplementalLabels,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}
