enum MemoryQuickFilter {
  saved,
  people,
  preferences;

  String get label {
    switch (this) {
      case MemoryQuickFilter.saved:
        return 'All';
      case MemoryQuickFilter.people:
        return 'People';
      case MemoryQuickFilter.preferences:
        return 'Preferences';
    }
  }
}
