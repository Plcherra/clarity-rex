import '../../features/plaid/application/plaid_connection_models.dart';
import '../../features/accounts/data/plaid_account_service.dart';
import '../../l10n/app_localizations.dart';
import '../supabase/supabase_exceptions.dart';
import '../../rex/chat/data/chat_api.dart';
import '../../rex/voice/data/cloud_voice_api.dart';
import '../../rex/voice/data/streaming_voice_api.dart';

/// Maps service-layer exceptions to user-facing localized strings.
///
/// Data services may keep English diagnostic messages for logs; presentation and
/// controllers should call this instead of showing [Exception.message] directly.
String friendlyServiceError(AppLocalizations l10n, Object error) {
  if (error is SupabaseDataException) {
    return friendlySupabaseDataError(l10n, error);
  }
  if (error is PlaidLinkServiceException) {
    return friendlyPlaidLinkError(l10n, error);
  }
  if (error is PlaidAccountServiceException) {
    return friendlyPlaidAccountError(l10n, error);
  }
  if (error is ChatApiException) {
    return friendlyChatApiError(l10n, error);
  }
  if (error is CloudVoiceApiException || error is StreamingVoiceApiException) {
    return friendlyVoiceApiError(l10n, error);
  }
  return l10n.serviceErrorGeneric;
}

String friendlySupabaseDataError(
  AppLocalizations l10n,
  SupabaseDataException error,
) {
  if (error is SupabaseAuthRequiredException) {
    return l10n.serviceErrorSignInRequired;
  }

  return switch ('${error.table}.${error.action}') {
    'accounts.fetchAccounts' => l10n.serviceErrorFetchAccounts,
    'accounts.createAccount' => l10n.serviceErrorCreateAccount,
    'accounts.updateAccount' => l10n.serviceErrorUpdateAccount,
    'accounts.deleteAccount' => l10n.serviceErrorDeleteAccount,
    'account_statement_imports.fetchImports' =>
      l10n.serviceErrorFetchStatementImports,
    'account_statement_imports.upsertImport' =>
      l10n.serviceErrorSaveStatementImport,
    'account_statement_imports.deleteImport' =>
      l10n.serviceErrorDeleteStatementImport,
    'transactions.fetchTransactions' => l10n.serviceErrorFetchTransactions,
    'transactions.createTransaction' => l10n.serviceErrorCreateTransaction,
    'transactions.createTransactions' => l10n.serviceErrorCreateTransactions,
    'transactions.updateTransaction' => l10n.serviceErrorUpdateTransaction,
    'transactions.updateTransactionsCategory' =>
      l10n.serviceErrorUpdateTransactionCategories,
    'transactions.deleteTransaction' => l10n.serviceErrorDeleteTransaction,
    'transactions.deleteTransactionsForImportBatch' =>
      l10n.serviceErrorDeleteCsvImportTransactions,
    'transactions.deleteTransactionsForAccountInDateRange' =>
      l10n.serviceErrorDeleteAccountTransactions,
    'budgets.fetchBudgets' => l10n.serviceErrorFetchBudgets,
    'budgets.createBudget' => l10n.serviceErrorCreateBudget,
    'budgets.updateBudget' => l10n.serviceErrorUpdateBudget,
    'budgets.updateBudgetsCategoryIdentity' =>
      l10n.serviceErrorUpdateBudgetCategories,
    'budgets.deleteBudget' => l10n.serviceErrorDeleteBudget,
    'categories.fetchCategories' => l10n.serviceErrorFetchCategories,
    'categories.createCategory' => l10n.serviceErrorCreateCategory,
    'categories.updateCategory' => l10n.serviceErrorUpdateCategory,
    'categories.deleteCategory' => l10n.serviceErrorDeleteCategory,
    'merchant_category_rules.fetchRules' =>
      l10n.serviceErrorFetchMerchantCategoryRules,
    'merchant_category_rules.upsertRule' =>
      l10n.serviceErrorSaveMerchantCategoryRule,
    'merchant_category_rules.updateRulesCategory' =>
      l10n.serviceErrorUpdateMerchantCategoryRules,
    'merchant_category_rules.updateRule' =>
      l10n.serviceErrorUpdateMerchantCategoryRule,
    'merchant_category_rules.deleteRule' =>
      l10n.serviceErrorDeleteMerchantCategoryRule,
    'financial_audit_events.recordEvent' => l10n.serviceErrorRecordAuditEvent,
    'financial_audit_events.fetchRecent' => l10n.serviceErrorFetchAuditEvents,
    _ => _genericSupabaseActionError(l10n, error.action),
  };
}

String _genericSupabaseActionError(AppLocalizations l10n, String action) {
  if (action.startsWith('fetch')) {
    return l10n.serviceErrorFetchGeneric;
  }
  if (action.startsWith('create') || action.startsWith('upsert')) {
    return l10n.serviceErrorCreateGeneric;
  }
  if (action.startsWith('update')) {
    return l10n.serviceErrorUpdateGeneric;
  }
  if (action.startsWith('delete')) {
    return l10n.serviceErrorDeleteGeneric;
  }
  return l10n.serviceErrorGeneric;
}

String friendlyPlaidLinkError(
  AppLocalizations l10n,
  PlaidLinkServiceException error,
) {
  final message = error.message.toLowerCase();
  if (message.contains('start bank connection')) {
    return l10n.plaidLinkStartFailed;
  }
  if (message.contains('save bank connection')) {
    return l10n.plaidLinkSaveFailed;
  }
  if (message.contains('parse bank connection')) {
    return l10n.plaidLinkParseFailed;
  }
  if (message.contains('missing plaid config')) {
    return l10n.plaidLinkConfigMissing;
  }
  if (message.contains('cancel')) {
    return l10n.plaidLinkCancelled;
  }
  return l10n.plaidLinkGenericFailed;
}

String friendlyPlaidAccountError(
  AppLocalizations l10n,
  PlaidAccountServiceException error,
) {
  final message = error.message.toLowerCase();
  if (message.contains('no connected bank')) {
    return l10n.plaidAccountNoConnectedBank;
  }
  if (message.contains('parse bank status')) {
    return l10n.plaidAccountParseStatusFailed;
  }
  return l10n.plaidAccountGenericFailed;
}

String friendlyChatApiError(AppLocalizations l10n, ChatApiException error) {
  return switch (error.type) {
    ChatApiErrorType.network => l10n.chatErrorNetwork,
    ChatApiErrorType.timeout => l10n.chatErrorTimeout,
    ChatApiErrorType.upload => l10n.chatErrorUpload,
    ChatApiErrorType.backendValidation => l10n.chatErrorValidation,
    ChatApiErrorType.invalidResponse => l10n.chatErrorInvalidResponse,
    ChatApiErrorType.unknown => l10n.chatPageSendFailed,
  };
}

String friendlyVoiceApiError(AppLocalizations l10n, Object error) {
  final message = switch (error) {
    CloudVoiceApiException(:final message) => message,
    StreamingVoiceApiException(:final message) => message,
    _ => '',
  }.toLowerCase();

  if (message.contains('auth') ||
      message.contains('token') ||
      message.contains('session') ||
      message.contains('expired') ||
      message.contains('unauthorized') ||
      message.contains('401')) {
    return l10n.voiceFailureSessionReconnect;
  }
  if (message.contains('empty_audio') ||
      message.contains('no audio') ||
      message.contains('did not catch') ||
      message.contains('did not hear') ||
      message.contains('blank transcript')) {
    return l10n.voiceFailureDidNotCatch;
  }
  if (message.contains('disconnect') ||
      message.contains('connection') ||
      message.contains('socket') ||
      message.contains('stream')) {
    return l10n.voiceFailureConnectionDropped;
  }
  if (message.contains('transcript')) {
    return l10n.voiceFailureTranscriptUnreadable;
  }
  if (message.contains('tts') ||
      message.contains('synthesize') ||
      message.contains('playback') ||
      message.contains('play rex voice') ||
      message.contains('play audio')) {
    return l10n.voiceFailurePlaybackFailed;
  }
  return l10n.voiceFailurePausedDefault;
}
