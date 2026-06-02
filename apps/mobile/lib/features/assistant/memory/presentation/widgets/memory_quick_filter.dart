import 'package:clarity/features/assistant/memory/data/memory_models.dart';

enum MemoryQuickFilter {
  saved,
  pending,
  corrections,
  people,
  preferences;

  MemoryReviewMode get targetMode {
    switch (this) {
      case MemoryQuickFilter.saved:
      case MemoryQuickFilter.people:
      case MemoryQuickFilter.preferences:
        return MemoryReviewMode.saved;
      case MemoryQuickFilter.pending:
      case MemoryQuickFilter.corrections:
        return MemoryReviewMode.pending;
    }
  }

  String label(int pendingCount) {
    switch (this) {
      case MemoryQuickFilter.saved:
        return 'Saved';
      case MemoryQuickFilter.pending:
        return pendingCount == 0 ? 'Pending' : 'Pending ($pendingCount)';
      case MemoryQuickFilter.corrections:
        return 'Corrections';
      case MemoryQuickFilter.people:
        return 'People';
      case MemoryQuickFilter.preferences:
        return 'Preferences';
    }
  }
}
