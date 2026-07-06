part of 'memory_controller.dart';

enum _MemoryOperation { load, edit, archive, create }

String _memoryErrorMessage(
  Ref ref,
  Object error,
  _MemoryOperation operation,
) {
  final l10n = _memoryL10n(ref);
  final statusCode = error is MemoryApiException ? error.statusCode : null;
  if (statusCode == 401 || statusCode == 403) {
    return l10n.memoryErrorSignInAgain;
  }
  if (statusCode == 404) {
    return l10n.memoryErrorNoLongerAvailable;
  }
  if (statusCode != null && statusCode >= 400 && statusCode < 500) {
    switch (operation) {
      case _MemoryOperation.create:
        return l10n.memoryErrorCreateValidation;
      case _MemoryOperation.edit:
        return l10n.memoryErrorEditValidation;
      case _MemoryOperation.archive:
        return l10n.memoryErrorArchiveRefresh;
      case _MemoryOperation.load:
        return l10n.memoryErrorLoadRefresh;
    }
  }

  switch (operation) {
    case _MemoryOperation.load:
      return l10n.memoryErrorLoadConnection;
    case _MemoryOperation.create:
      return l10n.memoryErrorCreateFailed;
    case _MemoryOperation.edit:
      return l10n.memoryErrorUpdateFailed;
    case _MemoryOperation.archive:
      return l10n.memoryErrorArchiveFailed;
  }
}

AppLocalizations _memoryL10n(Ref ref) {
  try {
    return lookupForLocale(ref.read(localeControllerProvider).locale);
  } on Object {
    return lookupEnglishLocalizationsForTests();
  }
}
