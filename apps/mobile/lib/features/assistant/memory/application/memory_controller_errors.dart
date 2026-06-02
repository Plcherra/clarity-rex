part of 'memory_controller.dart';

enum _MemoryOperation { load, approve, reject, edit, archive }

String _memoryErrorMessage(Object error, _MemoryOperation operation) {
  final statusCode = error is MemoryApiException ? error.statusCode : null;
  if (statusCode == 401 || statusCode == 403) {
    return 'Please sign in again to manage Rex Memory.';
  }
  if (statusCode == 404) {
    return 'That memory is no longer available.';
  }
  if (statusCode != null && statusCode >= 400 && statusCode < 500) {
    switch (operation) {
      case _MemoryOperation.edit:
        return 'That memory change could not be saved. Check the fields and try again.';
      case _MemoryOperation.approve:
        return 'That memory request could not be saved. Refresh Memory and try again.';
      case _MemoryOperation.reject:
        return 'That memory request could not be dismissed. Refresh Memory and try again.';
      case _MemoryOperation.archive:
        return 'That memory could not be archived. Refresh Memory and try again.';
      case _MemoryOperation.load:
        return 'Could not load Rex Memory. Refresh and try again.';
    }
  }

  switch (operation) {
    case _MemoryOperation.load:
      return 'Could not load Rex Memory. Check your connection and try again.';
    case _MemoryOperation.approve:
      return 'Could not save this memory. Please try again.';
    case _MemoryOperation.reject:
      return 'Could not dismiss this memory request. Please try again.';
    case _MemoryOperation.edit:
      return 'Could not update this memory. Please try again.';
    case _MemoryOperation.archive:
      return 'Could not archive this memory. Please try again.';
  }
}
