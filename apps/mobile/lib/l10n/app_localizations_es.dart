// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Clarity';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navBudgets => 'Budgets';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navProfile => 'Profile';

  @override
  String get loadingClarity => 'Loading Clarity';

  @override
  String get startingClarity => 'Starting Clarity';

  @override
  String get authSignInTitle => 'Sign in to Clarity';

  @override
  String get authSignUpTitle => 'Create your account';

  @override
  String get authSignInSubtitle => 'Use your email and password to continue.';

  @override
  String get authSignUpSubtitle =>
      'Use email and password to start your local finance workspace.';

  @override
  String get authFullNameLabel => 'Full name';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String get authSwitchToSignIn => 'Already have an account? Sign in';

  @override
  String get authSwitchToSignUp => 'Need an account? Create one';

  @override
  String get authEnterEmailPassword => 'Enter your email and password.';

  @override
  String get authEnterName => 'Enter your name to create a profile.';

  @override
  String get authEnterEmailForReset =>
      'Enter your email to reset your password.';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileLanguage => 'Language';

  @override
  String profileLanguageUpdated(String language) {
    return 'Language set to $language.';
  }

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get importUploadingTransactions => 'Uploading transactions...';

  @override
  String chatActionDoneSingle(String action) {
    return 'Done. I applied the $action change.';
  }

  @override
  String chatActionDoneForSubject(String action, String subject) {
    return 'Done. I applied the $action change for $subject.';
  }

  @override
  String chatActionDoneMultiple(String action, int count) {
    return 'Done. I applied the $action change to $count records.';
  }

  @override
  String chatActionDoneMultipleOne(String action) {
    return 'Done. I applied the $action change to 1 record.';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonArchive => 'Archive';

  @override
  String get commonMerge => 'Merge';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonOk => 'OK';

  @override
  String get commonKeep => 'Keep';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonIncome => 'Income';

  @override
  String get commonSpending => 'Spending';

  @override
  String get commonNet => 'Net';

  @override
  String get commonUnavailable => 'Unavailable';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonImport => 'Import';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonToday => 'Today';

  @override
  String get commonThisWeek => 'This week';

  @override
  String get commonThisMonth => 'This month';

  @override
  String get commonAll => 'All';

  @override
  String get commonCustom => 'Custom';

  @override
  String get commonActive => 'Active';

  @override
  String get commonTitle => 'Title';

  @override
  String get commonName => 'Name';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonPriority => 'Priority';

  @override
  String get commonImportance => 'Importance';

  @override
  String get commonSummary => 'Summary';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonType => 'Type';

  @override
  String get commonLow => 'Low';

  @override
  String get commonNormal => 'Normal';

  @override
  String get commonMedium => 'Medium';

  @override
  String get commonHigh => 'High';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonDueDate => 'Due date';

  @override
  String get commonAccount => 'Account';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonExpense => 'Expense';

  @override
  String get commonTransfer => 'Transfer';

  @override
  String get commonRefund => 'Refund';

  @override
  String get commonAdjustment => 'Adjustment';

  @override
  String get commonCreditCardPayment => 'Credit card payment';

  @override
  String get commonChecking => 'Checking';

  @override
  String get commonSavings => 'Savings';

  @override
  String get commonCard => 'Card';

  @override
  String get commonBuiltIn => 'Built-in';

  @override
  String get commonHidden => 'Hidden';

  @override
  String get commonVisible => 'Visible';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonCategories => 'Categories';

  @override
  String get commonRules => 'Rules';

  @override
  String get commonHistory => 'History';

  @override
  String get commonPeople => 'People';

  @override
  String get commonPreferences => 'Preferences';

  @override
  String get commonPerson => 'Person';

  @override
  String get commonPlan => 'Plan';

  @override
  String get commonCommitment => 'Commitment';

  @override
  String get commonRule => 'Rule';

  @override
  String get commonMemory => 'Memory';

  @override
  String get commonConversation => 'Conversation';

  @override
  String get commonUndated => 'Undated';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonOlder => 'Older';

  @override
  String get commonUpcoming => 'Upcoming';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonAttachment => 'Attachment';

  @override
  String get commonStart => 'Start';

  @override
  String get commonEnd => 'End';

  @override
  String get commonLeft => 'Left';

  @override
  String get commonOver => 'Over';

  @override
  String get commonSpent => 'Spent';

  @override
  String get commonBudgeted => 'Budgeted';

  @override
  String get commonMonthly => 'Monthly';

  @override
  String get commonWeekly => 'Weekly';

  @override
  String commonOnTrack(int onTrack, int budgeted) {
    return '$onTrack/$budgeted on track';
  }

  @override
  String commonTransactionCount(int count) {
    return '$count transactions';
  }

  @override
  String get commonTransactionCountOne => '1 transaction';

  @override
  String commonRecordsApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return 'Applied to $_temp0.';
  }

  @override
  String commonAiCalls(int count) {
    return '$count AI calls';
  }

  @override
  String commonAiCallsThisMonth(int count) {
    return '$count AI calls this month';
  }

  @override
  String commonMinutesFormat(String minutes) {
    return '$minutes min';
  }

  @override
  String get commonMinutesUnderOne => '<1 min';

  @override
  String commonAddedDate(String date) {
    return 'Added $date';
  }

  @override
  String commonUpdatedDate(String date) {
    return 'Updated $date';
  }

  @override
  String commonDueDateValue(String date) {
    return 'Due $date';
  }

  @override
  String commonTargetDateValue(String date) {
    return 'Target $date';
  }

  @override
  String commonLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String commonAcrossAccounts(int accountCount, String accountCountSuffix) {
    return 'Across $accountCount connected account$accountCountSuffix';
  }

  @override
  String commonConnectedAccountCount(int count, String countSuffix) {
    return '$count connected account$countSuffix';
  }

  @override
  String commonCopiedLabel(String label) {
    return '$label copied.';
  }

  @override
  String commonArchivedNamed(String label) {
    return '$label archived';
  }

  @override
  String get commonCommaSeparated => 'Comma-separated';

  @override
  String get commonAmountHintDash => '—';

  @override
  String commonMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get commonMonthJanuary => 'January';

  @override
  String get commonMonthFebruary => 'February';

  @override
  String get commonMonthMarch => 'March';

  @override
  String get commonMonthApril => 'April';

  @override
  String get commonMonthMay => 'May';

  @override
  String get commonMonthJune => 'June';

  @override
  String get commonMonthJuly => 'July';

  @override
  String get commonMonthAugust => 'August';

  @override
  String get commonMonthSeptember => 'September';

  @override
  String get commonMonthOctober => 'October';

  @override
  String get commonMonthNovember => 'November';

  @override
  String get commonMonthDecember => 'December';

  @override
  String get commonMonthShortJan => 'Jan';

  @override
  String get commonMonthShortFeb => 'Feb';

  @override
  String get commonMonthShortMar => 'Mar';

  @override
  String get commonMonthShortApr => 'Apr';

  @override
  String get commonMonthShortMay => 'May';

  @override
  String get commonMonthShortJun => 'Jun';

  @override
  String get commonMonthShortJul => 'Jul';

  @override
  String get commonMonthShortAug => 'Aug';

  @override
  String get commonMonthShortSep => 'Sep';

  @override
  String get commonMonthShortOct => 'Oct';

  @override
  String get commonMonthShortNov => 'Nov';

  @override
  String get commonMonthShortDec => 'Dec';

  @override
  String get commonMonthShortOld => 'Old';

  @override
  String get bootErrorTitle => 'Clarity could not start';

  @override
  String get bootErrorTryAgain => 'Try again';

  @override
  String get bootErrorFallbackMessage => 'Check your connection and try again.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Clarity';

  @override
  String get onboardingSubtitle =>
      'Name your Clarity space. Next, you can connect your bank or use CSV as a manual fallback.';

  @override
  String get onboardingNameLabel => 'Your name';

  @override
  String get onboardingNameHint => 'Pedro';

  @override
  String get profileScreenTitle => 'Profile';

  @override
  String get profileEditNameTitle => 'Edit profile name';

  @override
  String get profileUpdatedSnackBar => 'Profile updated.';

  @override
  String get profileUpdateFailed => 'Could not update profile.';

  @override
  String get profileSignOutTitle => 'Sign out?';

  @override
  String get profileSignOutBody => 'You can sign back in when you are ready.';

  @override
  String get profileDefaultUserName => 'Clarity user';

  @override
  String get profileAccountSection => 'Account';

  @override
  String get profileNameTitle => 'Profile name';

  @override
  String get profileAddYourName => 'Add your name';

  @override
  String get profileMfaTitle => 'Multi-factor authentication';

  @override
  String get profileMfaSubtitle =>
      'Authenticator app setup and security options';

  @override
  String get profileRexVoiceSection => 'Rex and voice';

  @override
  String get profileVoiceUsageTitle => 'Voice usage';

  @override
  String get profileVoiceUsageSubtitle =>
      'Minutes today, this week, and this month';

  @override
  String get profileSessionSection => 'Session';

  @override
  String get profileSignOutSubtitle =>
      'Leave this device signed out of Clarity';

  @override
  String get profileHeaderLabel => 'Clarity profile';

  @override
  String get usageSummaryTitle => 'Voice usage';

  @override
  String get usageSummaryLoading => 'Loading usage';

  @override
  String get usageSummaryDailyVoiceMinutes => 'Daily voice minutes';

  @override
  String get usageSummaryDailyAiCalls => 'Daily AI calls';

  @override
  String get usageSummaryHeaderLabel => 'Rex voice activity';

  @override
  String homeShellBankConnectedSuccess(
    String institutionName,
    String accountsSyncedSuffix,
  ) {
    return 'Bank connected successfully: $institutionName$accountsSyncedSuffix.';
  }

  @override
  String get homeShellBankConnectedYourBank => 'your bank';

  @override
  String homeShellBankConnectedAccountsSynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return ' and synced $_temp0';
  }

  @override
  String homeShellBankConnectionStoppedWithCode(String errorCode) {
    return 'Bank connection stopped before it finished. You can try again. ($errorCode)';
  }

  @override
  String homeShellBankConnectionStoppedWithStatus(String status) {
    return 'Bank connection stopped before it finished. Plaid status: $status.';
  }

  @override
  String get homeShellBankConnectionCancelled =>
      'Bank connection cancelled. No account was added.';

  @override
  String get homeShellBankConnectionOpenFailed =>
      'Could not open bank connection.';

  @override
  String get dashboardOverviewTitle => 'Overview';

  @override
  String get dashboardOverviewImportCsvTooltip => 'Import CSV instead';

  @override
  String get dashboardOverviewDeleteCsvUploadTooltip => 'Delete CSV upload';

  @override
  String get dashboardOverviewDeleteAccountTooltip => 'Delete account';

  @override
  String get dashboardOverviewMonthlyCashFlow => 'Monthly cash flow';

  @override
  String get dashboardOverviewSpendingByCategory => 'Spending by category';

  @override
  String get dashboardOverviewIncomeVsSpending => 'Income vs spending';

  @override
  String get dashboardOverviewSixMonthTrend => 'Six-month spend trend';

  @override
  String get dashboardOverviewSpendingPressure => 'Spending pressure';

  @override
  String get dashboardOverviewBudgetPerformance => 'Budget performance';

  @override
  String get dashboardOverviewAccountHealth => 'Account health';

  @override
  String get dashboardOverviewDataLoadBannerTitle =>
      'Some financial data could not load';

  @override
  String dashboardOverviewDataLoadBannerBody(String sourceLabel) {
    return 'Clarity is showing the available records, but $sourceLabel may be incomplete. Rex will treat finance answers as degraded until this refreshes.';
  }

  @override
  String get dashboardOverviewDataLoadBannerFallbackSource => 'financial data';

  @override
  String get dashboardOverviewLoadingLabel => 'Loading your financial data...';

  @override
  String get dashboardEmptyConnectFirstBankTitle => 'Connect your first bank';

  @override
  String get dashboardEmptyConnectFirstBankBody =>
      'Clarity works best with connected accounts, so balances and transactions stay current automatically.';

  @override
  String get dashboardResolvingTitle => 'Resolving imported transactions';

  @override
  String get dashboardResolvingBody =>
      'Your statement is connected, but the transaction rows are still loading. Values will appear when the read model is complete.';

  @override
  String get dashboardOverviewTotalBalance => 'Total balance';

  @override
  String get dashboardOverviewAccountBalance => 'Account balance';

  @override
  String get dashboardOverviewFromConnectedAccounts =>
      'From your connected accounts';

  @override
  String get dashboardOverviewThisMonthLabel => 'This month';

  @override
  String get dashboardOverviewActivityNotBalanceNote =>
      'Activity this month — not the same as balance';

  @override
  String get dashboardTransactionsSectionTitle => 'Transactions';

  @override
  String get dashboardTransactionsClearFilters => 'Clear';

  @override
  String get dashboardTransactionsLoadingLabel => 'Loading transactions';

  @override
  String get dashboardTransactionsLoadError => 'Could not load transactions.';

  @override
  String get dashboardTransactionsNoImportedHistory => 'No imported history';

  @override
  String get dashboardTransactionsModeMonths => 'Months';

  @override
  String get dashboardTransactionsModeCategories => 'Categories';

  @override
  String get dashboardTransactionsSearchHint =>
      'Search merchant, category, month, or amount';

  @override
  String get dashboardTransactionsFilterCategory => 'Category';

  @override
  String get dashboardTransactionsFilterAllCategories => 'All categories';

  @override
  String get dashboardTransactionsFilterAccount => 'Account';

  @override
  String get dashboardTransactionsFilterAllAccounts => 'All accounts';

  @override
  String get dashboardTransactionsFilterRole => 'Role';

  @override
  String get dashboardTransactionsFilterAllRoles => 'All roles';

  @override
  String get dashboardTransactionsTimeFilterAllHistory => 'All history';

  @override
  String get dashboardTransactionsTimeFilterDashboardMonth => 'Dashboard month';

  @override
  String get dashboardTransactionsTimeFilterLatestTxMonth => 'Latest tx month';

  @override
  String get dashboardTransactionsTimeFilterLatestTxYear => 'Latest tx year';

  @override
  String get dashboardTransactionsSortNewest => 'Newest';

  @override
  String get dashboardTransactionsSortOldest => 'Oldest';

  @override
  String get dashboardTransactionsSortLargest => 'Largest';

  @override
  String get dashboardTransactionsSortMerchant => 'Merchant A-Z';

  @override
  String get dashboardTransactionsNoCategoriesMatch => 'No categories match.';

  @override
  String get dashboardTransactionsNoMonthsAfterFilter =>
      'No months to show after filtering this file.';

  @override
  String get dashboardTransactionsNetLabel => 'net';

  @override
  String dashboardTransactionsHistoryRange(String dateRange) {
    return 'History: $dateRange';
  }

  @override
  String dashboardTransactionsDashboardMonthRange(String dateRange) {
    return 'Dashboard month: $dateRange';
  }

  @override
  String dashboardTransactionsLatestTxMonthRange(String dateRange) {
    return 'Latest transaction month: $dateRange';
  }

  @override
  String dashboardTransactionsLatestTxYearRange(String dateRange) {
    return 'Latest transaction year: $dateRange';
  }

  @override
  String dashboardTransactionsTapMonthHint(String dateRangeDescription) {
    return 'Tap a month to inspect transactions | $dateRangeDescription';
  }

  @override
  String dashboardTransactionsFilteredCount(
    int filtered,
    int total,
    String dateRangeDescription,
  ) {
    return '$filtered of $total transactions | $dateRangeDescription';
  }

  @override
  String get accountsScreenRefreshTooltip => 'Refresh accounts';

  @override
  String get accountsScreenAddAccountTooltip => 'Add account';

  @override
  String get accountsScreenLoadError => 'Could not load accounts.';

  @override
  String get accountsScreenLoadingLabel => 'Loading accounts';

  @override
  String get accountsSummaryTotalBalance => 'Total balance';

  @override
  String get accountsEmptyTitle => 'Connect your accounts';

  @override
  String get accountsEmptyBody =>
      'Start with connected bank accounts so Clarity can keep balances and transactions current.';

  @override
  String get connectBankCardConnectButton => 'Connect Bank';

  @override
  String get connectBankCardImportCsvButton => 'Import CSV instead';

  @override
  String get connectBankCardAddManualButton => 'Add manual account';

  @override
  String get accountsNoticeDismissTooltip => 'Dismiss';

  @override
  String accountTileThisMonthNet(String amount) {
    return 'This month $amount net';
  }

  @override
  String get accountTileViewAccount => 'View account';

  @override
  String get plaidAccountAvailableLabel => 'Available';

  @override
  String get plaidAccountThisMonthLabel => 'This month';

  @override
  String plaidAccountInOutSummary(String income, String spending) {
    return '$income in / $spending out';
  }

  @override
  String get plaidAccountLastSyncedUnavailable => 'Last synced unavailable';

  @override
  String get plaidAccountLastSyncedJustNow => 'Last synced just now';

  @override
  String plaidAccountLastSyncedMinutesAgo(int minutes) {
    return 'Last synced ${minutes}m ago';
  }

  @override
  String plaidAccountLastSyncedHoursAgo(int hours) {
    return 'Last synced ${hours}h ago';
  }

  @override
  String plaidAccountLastSyncedDate(String date) {
    return 'Last synced $date';
  }

  @override
  String get plaidAccountResyncTooltipSyncing => 'Syncing';

  @override
  String get plaidAccountResyncTooltipLoginRequired => 'Login required';

  @override
  String get plaidAccountResyncTooltipExpiringSoon => 'Expiring soon';

  @override
  String get plaidAccountResyncTooltipDisconnected => 'Disconnected';

  @override
  String get plaidAccountResyncTooltipDefault => 'Resync';

  @override
  String get plaidAccountDisconnectTooltip => 'Disconnect bank';

  @override
  String get addAccountDialogTitle => 'New account';

  @override
  String get addAccountDialogInstitutionLabel => 'Institution (optional)';

  @override
  String get addAccountDialogTypeLabel => 'Type';

  @override
  String get addAccountDialogBalanceLabel => 'Current balance (optional)';

  @override
  String get addAccountDialogInvalidBalance =>
      'Enter a valid balance or leave it blank.';

  @override
  String get accountsSheetAddAccountTitle => 'Add account';

  @override
  String get accountsSheetAddAccountSubtitle =>
      'Connect another bank with Plaid, or use manual tools when you need a fallback.';

  @override
  String get accountsSheetConnectBankTitle => 'Connect bank';

  @override
  String get accountsSheetConnectBankSubtitle =>
      'Use Plaid to add another bank.';

  @override
  String get accountsSheetImportCsvTitle => 'Import CSV instead';

  @override
  String get accountsSheetImportCsvSubtitle =>
      'Create a manual account for bank files.';

  @override
  String get accountsSheetAddManualTitle => 'Add manual account';

  @override
  String get accountsSheetAddManualSubtitle =>
      'Track an account without Plaid.';

  @override
  String get accountsScreenDisconnectTitle => 'Disconnect bank?';

  @override
  String accountsScreenDisconnectContent(String accountName) {
    return 'Disconnect $accountName? This stops future Plaid sync for this bank. Existing history stays in Clarity.';
  }

  @override
  String get accountsScreenDisconnectButton => 'Disconnect bank';

  @override
  String get accountsScreenBankDisconnectedSnack => 'Bank disconnected.';

  @override
  String get accountsNavigationCouldNotSaveAccount => 'Could not save account.';

  @override
  String get csvPlaidWarningTitle => 'Import CSV into connected account?';

  @override
  String csvPlaidWarningContent(String accountName) {
    return '$accountName already syncs through Plaid. Importing a CSV here can add duplicate rows if the file overlaps with synced transactions.';
  }

  @override
  String get csvPlaidWarningContinue => 'Continue import';

  @override
  String get accountSelectionAppBarTitle => 'Import CSV instead';

  @override
  String get accountSelectionPreviewingCsv => 'Previewing CSV...';

  @override
  String get accountSelectionCouldNotImport => 'Could not import this file.';

  @override
  String get accountSelectionEmptyTitle => 'Add a manual account for this CSV';

  @override
  String get accountSelectionAddManualButton => 'Add manual account';

  @override
  String get accountSelectionInstructions =>
      'CSV import is manual. Choose the account this file belongs to; connected bank accounts update automatically.';

  @override
  String get accountSelectionCsvMayDuplicate => 'CSV may duplicate synced rows';

  @override
  String get csvPreviewDialogTitle => 'CSV import preview';

  @override
  String get csvPreviewDialogDateRange => 'Date range';

  @override
  String get csvPreviewDialogRowsFound => 'Rows found';

  @override
  String get csvPreviewDialogNewRows => 'New rows';

  @override
  String get csvPreviewDialogDuplicates => 'Duplicates';

  @override
  String get csvPreviewDialogSpendingRows => 'Spending rows';

  @override
  String get csvPreviewDialogIncomeRows => 'Income rows';

  @override
  String get csvPreviewDialogEndingBalance => 'Ending balance';

  @override
  String get csvPreviewDialogNoNewRows => 'No new rows';

  @override
  String get accountDetailFallbackTitle => 'Account';

  @override
  String get accountDetailLoadingLabel => 'Loading account';

  @override
  String get accountDetailLoadError => 'Could not load account.';

  @override
  String get accountDetailDeletingCsvProgress => 'Deleting CSV upload...';

  @override
  String get accountDetailDeleteCsvUploadTitle => 'Delete CSV upload';

  @override
  String get accountDetailConfirmDeleteCsvTitle => 'Delete this CSV upload?';

  @override
  String get accountDetailDeleteUploadButton => 'Delete upload';

  @override
  String get accountDetailDeleteAccountTitle => 'Delete account?';

  @override
  String get accountDetailDeleteAccountContent =>
      'Delete this account and all its transactions? This cannot be undone.';

  @override
  String get accountDetailDeleteAccountButton => 'Delete account';

  @override
  String get accountDetailKeepCategories => 'Keep';

  @override
  String get accountDetailDeleteCategories => 'Delete';

  @override
  String get chatPageDefaultTitle => 'Rex';

  @override
  String get chatPageSendingImage => 'Sending image…';

  @override
  String get chatPageSendFailed => 'Could not send message.';

  @override
  String get chatPageReadFileFailed => 'Could not read selected file.';

  @override
  String get chatPageStartVoiceFailed => 'Could not start Rex.';

  @override
  String get chatPageShowVoiceCallTooltip => 'Show voice call';

  @override
  String get chatPageCallRexTooltip => 'Call Rex';

  @override
  String get chatInputAttachTooltip => 'Attach file or image';

  @override
  String get chatInputStartVoiceModeTooltip => 'Start voice mode';

  @override
  String get chatInputMessageHint => 'Message Assistant…';

  @override
  String get chatInputSendTooltip => 'Send';

  @override
  String get chatInputRemoveAttachmentTooltip => 'Remove attachment';

  @override
  String get attachmentSheetTitle => 'Attach';

  @override
  String get attachmentSheetGalleryTitle => 'Gallery';

  @override
  String get attachmentSheetGallerySubtitle => 'Choose an image from photos.';

  @override
  String get attachmentSheetCameraTitle => 'Camera';

  @override
  String get attachmentSheetCameraSubtitle => 'Take a new photo.';

  @override
  String get attachmentSheetFilesTitle => 'Files';

  @override
  String get attachmentSheetFilesSubtitle =>
      'Choose PDF, text, CSV, markdown, or image files.';

  @override
  String get chatTranscriptWelcomeMessage =>
      'I\'m Rex. Tell me what\'s happening, what changed, or what you want me to remember.';

  @override
  String get chatTranscriptReadyTitle => 'Rex is ready';

  @override
  String get chatTranscriptPromptRemember => 'What should I remember?';

  @override
  String get chatTranscriptPromptThinkTonight =>
      'Help me think through tonight.';

  @override
  String get chatTranscriptPromptCheckKnows => 'Check what Clarity knows.';

  @override
  String get chatBubbleClarityAction => 'Clarity action';

  @override
  String get voicePanelStartTalking => 'Start talking';

  @override
  String get voicePanelProcessing => 'Processing…';

  @override
  String get voicePanelMuted => 'Muted';

  @override
  String get voicePanelSettingsTooltip => 'Settings';

  @override
  String get voicePanelTryAgainTooltip => 'Try again';

  @override
  String get voicePanelUnmuteMicTooltip => 'Unmute mic';

  @override
  String get voicePanelMuteMicTooltip => 'Mute mic';

  @override
  String get voicePanelEndVoiceTooltip => 'End voice';

  @override
  String get conversationListTitle => 'Chats';

  @override
  String get conversationListDeleteTitle => 'Delete conversation?';

  @override
  String get conversationListDeleteBody =>
      'This removes the conversation and its messages.';

  @override
  String get conversationListDeleteFailed => 'Could not delete conversation.';

  @override
  String get conversationListDeletedSnackBar => 'Conversation deleted';

  @override
  String get conversationListNewConversationTooltip => 'New conversation';

  @override
  String get conversationListLoading => 'Loading chats';

  @override
  String get conversationListEmptyTitle => 'No chats yet';

  @override
  String get conversationListEmptyMessage =>
      'Start a fresh conversation when you are ready.';

  @override
  String get conversationListSearchHint => 'Search chats';

  @override
  String get conversationListClearSearchTooltip => 'Clear search';

  @override
  String get conversationListSearching => 'Searching chats';

  @override
  String get conversationListNoMatchesTitle => 'No matching chats';

  @override
  String get conversationListNewChat => 'New chat';

  @override
  String get conversationHistoryNewConversation => 'New conversation';

  @override
  String get conversationHistoryMatchedConversation => 'Matched conversation';

  @override
  String get conversationHistoryNoMessagesYet => 'No messages yet';

  @override
  String get conversationHistoryActionsTooltip => 'Conversation actions';

  @override
  String get memoryPageTitle => 'What Clarity Knows';

  @override
  String get memoryPageRefreshTooltip => 'Refresh information';

  @override
  String get memoryPageMemoryUpdated => 'Memory updated';

  @override
  String get memoryPageMemoryArchived => 'Memory archived';

  @override
  String get memoryPageActionFailed => 'Memory action failed.';

  @override
  String get memoryHeaderSearchHint => 'Search what Clarity knows';

  @override
  String get memoryHeaderClearSearchTooltip => 'Clear search';

  @override
  String get memoryHeaderSectionTitle => 'What Clarity knows';

  @override
  String get memoryHeaderActiveOnly => 'Active information only';

  @override
  String get memoryHeaderLoading => 'Loading memory';

  @override
  String get memoryHeaderEmptyActiveTitle => 'Clarity is still learning';

  @override
  String get memoryHeaderEmptyTitle => 'No saved information yet';

  @override
  String get memoryArchiveTitle => 'Archive saved information?';

  @override
  String get memoryArchiveBody =>
      'This saved information will stop being used in future conversations. It will remain in information history.';

  @override
  String get memoryTileActionsTooltip => 'Memory actions';

  @override
  String get memoryTileQuickEdit => 'Quick edit';

  @override
  String get memoryEditEditMemoryTitle => 'Edit memory';

  @override
  String get memoryEditSummaryHint => 'What Clarity should remember';

  @override
  String get accountabilityPageTitle => 'Goals';

  @override
  String get accountabilityPageRefreshTooltip => 'Refresh goals';

  @override
  String get accountabilitySharedAddGoal => 'Add goal';

  @override
  String get accountabilitySharedAddCommitment => 'Add commitment';

  @override
  String get accountabilitySharedLoading => 'Loading goals';

  @override
  String get accountabilitySharedEmptyTitle => 'No goals yet';

  @override
  String get accountabilitySharedEmptyBody =>
      'Start with one simple goal or tell Rex in chat.';

  @override
  String get accountabilitySharedAddFirstGoal => 'Add your first goal';

  @override
  String get accountabilitySectionsActiveGoals => 'Active Goals';

  @override
  String get accountabilitySectionsNoActiveGoals => 'No active goals yet.';

  @override
  String get accountabilitySectionsOpenCommitments => 'Open Commitments';

  @override
  String get accountabilitySectionsNoOpenCommitments => 'No open commitments.';

  @override
  String get accountabilityTilesGoalActionsTooltip => 'Goal actions';

  @override
  String get accountabilityTilesCommitmentActionsTooltip =>
      'Commitment actions';

  @override
  String get accountabilityTilesMarkMissed => 'Mark missed';

  @override
  String get accountabilityDetailGoalDetails => 'Goal details';

  @override
  String get accountabilityDetailEditCommitment => 'Edit commitment';

  @override
  String get accountabilityDetailNotesHint => 'Why this matters';

  @override
  String get budgetsScreenManageCategoriesTooltip => 'Manage categories';

  @override
  String get budgetsScreenSaveChangesTooltip => 'Save changes';

  @override
  String get budgetsScreenLoadError => 'Could not load budgets.';

  @override
  String get budgetsScreenLoadingLabel => 'Loading budgets';

  @override
  String get budgetsScreenBudgetVsSpentTitle => 'Budget vs spent';

  @override
  String get budgetsHeaderSelectMonth => 'Select month';

  @override
  String get budgetsHeaderPickWeekStart => 'Pick week start';

  @override
  String get budgetsHeaderNoMonthsAvailable => 'No months available.';

  @override
  String get budgetsScreenUnsavedChangesTitle =>
      'Save changes before switching period?';

  @override
  String get budgetsScreenUnsavedChangesContent =>
      'You have unsaved budget changes for this period.';

  @override
  String get budgetsScreenSaveFailedSnack =>
      'Could not save budgets. Try again.';

  @override
  String get budgetCategoryListTitle => 'Categories';

  @override
  String get budgetCategoryListEmpty => 'No active budget categories yet.';

  @override
  String budgetCategoryRowStatusNoBudget(String spent) {
    return 'Spent $spent · No budget';
  }

  @override
  String budgetCategoryRowStatusOver(String spent, String amount) {
    return 'Spent $spent · Over $amount';
  }

  @override
  String budgetCategoryRowStatusLeft(String spent, String amount) {
    return 'Spent $spent · Left $amount';
  }

  @override
  String get categorySheetHeaderTitle => 'Manage categories';

  @override
  String get categorySheetAddCustomCategory => 'Add custom category';

  @override
  String get categorySheetSavedCategoriesLabel => 'Saved categories';

  @override
  String get categorySheetNoSavedCategories => 'No saved categories yet.';

  @override
  String get categorySheetMerchantRulesLabel => 'Merchant rules';

  @override
  String get categorySheetNoMerchantRules => 'No learned merchant rules yet.';

  @override
  String get categorySheetRecentChangesLabel => 'Recent changes';

  @override
  String get categorySheetNoAuditEvents => 'No financial changes recorded yet.';

  @override
  String get categoryDialogNameLabel => 'Category name';

  @override
  String get categorySheetAddCategoryTitle => 'Add category';

  @override
  String get categorySheetRenameCategoryTitle => 'Rename category';

  @override
  String get categorySheetDeleteCategoryTitle => 'Delete category?';

  @override
  String get categorySheetMergeCategoryTitle => 'Merge category?';

  @override
  String get categorySheetMergeButton => 'Merge';

  @override
  String get categorySheetCategoryInUseTitle => 'Category is in use';

  @override
  String get categorySheetClose => 'Close';

  @override
  String get transactionCategoryAutoRole => 'Auto role';

  @override
  String get transactionCategoryFinancialRoleTooltip => 'Financial role';

  @override
  String get transactionCategoryNoCategories => 'No categories';

  @override
  String get transactionCategoryNewCategoryHint => 'New category';

  @override
  String get transactionCategoryOnlyThisOne => 'Only this one';

  @override
  String get transactionCategoryUpdatedSnack => 'Category updated.';

  @override
  String budgetsScreenSavedSnack(String period) {
    return 'Budgets saved for $period';
  }

  @override
  String get categorySheetLoadingLabel => 'Loading categories';

  @override
  String get categorySheetLoadError => 'Could not load categories.';

  @override
  String get categorySheetCategoryAddedSnack => 'Category added.';

  @override
  String get categorySheetCategoryRenamedSnack => 'Category renamed.';

  @override
  String categorySheetDeleteCategoryContent(String name) {
    return '\"$name\" is not used by transactions, budgets, or merchant rules. Delete it from saved custom categories?';
  }

  @override
  String get categorySheetCategoryDeletedSnack => 'Category deleted.';

  @override
  String get categorySheetCategoryShownSnack => 'Category shown in pickers.';

  @override
  String get categorySheetCategoryHiddenSnack =>
      'Category hidden from pickers.';

  @override
  String categorySheetMergeCategoryContent(
    String source,
    String target,
    String usage,
  ) {
    return 'Merge \"$source\" into \"$target\"? This will move $usage to \"$target\" and delete \"$source\".';
  }

  @override
  String get categorySheetCategoryMergedSnack => 'Category merged.';

  @override
  String categorySheetCategoryInUseContent(String name, String usage) {
    return '\"$name\" is used by $usage. Merge it into another category or hide it from pickers instead of deleting it.';
  }

  @override
  String get categorySheetNoMergeTarget =>
      'No visible target category to merge into.';

  @override
  String categorySheetMergeIntoTitle(String source) {
    return 'Merge \"$source\" into';
  }

  @override
  String get categorySheetNoRuleCategory =>
      'No visible category is available for this rule.';

  @override
  String get categorySheetSetMerchantRuleCategoryTitle =>
      'Set merchant rule category';

  @override
  String get categorySheetUpdateFutureImportsTitle => 'Update future imports?';

  @override
  String categorySheetUpdateFutureImportsContent(
    String merchant,
    String category,
  ) {
    return 'Future \"$merchant\" imports will use \"$category\". Existing transactions will not be changed.';
  }

  @override
  String get categorySheetUpdateRuleButton => 'Update rule';

  @override
  String get categorySheetMerchantRuleUpdatedSnack => 'Merchant rule updated.';

  @override
  String get categorySheetDisableRuleTitle => 'Disable rule?';

  @override
  String get categorySheetEnableRuleTitle => 'Enable rule?';

  @override
  String categorySheetDisableRuleContent(String merchant) {
    return 'Future \"$merchant\" imports will stop using this learned category rule.';
  }

  @override
  String categorySheetEnableRuleContent(String merchant) {
    return 'Future \"$merchant\" imports will use this learned category rule again.';
  }

  @override
  String get categorySheetMerchantRuleDisabledSnack =>
      'Merchant rule disabled.';

  @override
  String get categorySheetMerchantRuleEnabledSnack => 'Merchant rule enabled.';

  @override
  String get categorySheetDeleteMerchantRuleTitle => 'Delete merchant rule?';

  @override
  String categorySheetDeleteMerchantRuleContent(String merchant) {
    return 'Future \"$merchant\" imports will no longer use this learned category rule.';
  }

  @override
  String get categorySheetMerchantRuleDeletedSnack => 'Merchant rule deleted.';

  @override
  String categorySheetSaveFailedSnack(String error) {
    return 'Could not save changes: $error';
  }

  @override
  String categorySheetBuiltInHint(int count) {
    return 'Built-in budget categories are always available: $count. Used custom categories must be merged or hidden before deletion.';
  }

  @override
  String get categorySheetMerchantRulesHint =>
      'Merchant rules affect future CSV imports. Editing a rule does not rewrite existing transactions.';

  @override
  String get categorySheetCategoryActionsTooltip => 'Category actions';

  @override
  String get categorySheetShowInPickers => 'Show in pickers';

  @override
  String get categorySheetHideFromPickers => 'Hide from pickers';

  @override
  String get commonRename => 'Rename';

  @override
  String get categorySheetChangeCategory => 'Change category';

  @override
  String get categorySheetEnableRule => 'Enable rule';

  @override
  String get categorySheetDisableRule => 'Disable rule';

  @override
  String get categorySheetDeleteRule => 'Delete rule';

  @override
  String get categorySheetMerchantRuleActionsTooltip => 'Merchant rule actions';

  @override
  String get categorySheetMissingCategory => 'Missing category';

  @override
  String get categorySheetAuditTransactionCategoryChanged =>
      'Transaction category changed';

  @override
  String get categorySheetAuditBulkCategoryChange => 'Bulk category change';

  @override
  String get categorySheetAuditTransactionRoleChanged =>
      'Transaction role changed';

  @override
  String get categorySheetAuditCategoryDeleted => 'Category deleted';

  @override
  String get categorySheetAuditCategoryMerged => 'Category merged';

  @override
  String get categorySheetAuditCategoryVisibilityChanged =>
      'Category visibility changed';

  @override
  String get categorySheetAuditMerchantRuleChanged => 'Merchant rule changed';

  @override
  String get categorySheetAuditMerchantRuleEnabledDisabled =>
      'Merchant rule enabled/disabled';

  @override
  String get categorySheetAuditMerchantRuleDeleted => 'Merchant rule deleted';

  @override
  String get categorySheetAuditCategoryRenamed => 'Category renamed';

  @override
  String categoryUsageTxCount(int count) {
    return '$count tx';
  }

  @override
  String categoryUsageBudgetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets',
      one: '1 budget',
    );
    return '$_temp0';
  }

  @override
  String categoryUsageRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String merchantRuleStatsMatchingTx(int count) {
    return '$count matching tx';
  }

  @override
  String merchantRuleStatsMatchingTxLastUsed(int count, String date) {
    return '$count matching tx · last used $date';
  }

  @override
  String get transactionCategoryNotFoundSnack =>
      'Could not find this transaction.';

  @override
  String transactionCategoryUpdateRoleFailed(String error) {
    return 'Could not update role: $error';
  }

  @override
  String transactionCategoryDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get transactionCategoryDeleteContent =>
      'Remove this category and clear it from assigned transactions?';

  @override
  String transactionCategoryUpdateFailed(String error) {
    return 'Could not update category: $error';
  }

  @override
  String get transactionCategoryApplySimilarTitle =>
      'Apply to similar transactions?';

  @override
  String transactionCategoryApplySimilarContent(int count, String merchant) {
    return 'Clarity found $count transactions that look like \"$merchant\". Apply this category to all of them and remember it for future CSV imports?';
  }

  @override
  String transactionCategoryUpdateCount(int count) {
    return 'Update $count';
  }

  @override
  String transactionCategoryUpdatedSimilarSnack(int count) {
    return 'Updated $count similar transactions. Choose another category to correct them.';
  }

  @override
  String get transactionCategoryUpdatedFutureImportsSnack =>
      'Category updated. Future matching imports will use it.';

  @override
  String get importJobCompleteSnack => 'Import complete.';

  @override
  String importJobCategoryAssignmentFailedSnack(int inserted) {
    return 'Imported $inserted transactions, but category assignment failed.';
  }

  @override
  String importJobCategoryRetryNeededPersistent(int inserted, int failures) {
    return 'Imported $inserted transactions, but $failures need category assignment retry.';
  }

  @override
  String get importJobNeedsCategoryRetryTitle => 'Import needs category retry';

  @override
  String importJobNoNewTransactionsDuplicates(int skipped) {
    return 'No new transactions imported. $skipped duplicates skipped.';
  }

  @override
  String get importJobNoNewTransactions => 'No new transactions imported.';

  @override
  String importJobSuccessWithLocalAndMisc(int inserted, int local, int misc) {
    return 'Imported $inserted transactions. Categorized all; $local used local rules; $misc used a best-guess category.';
  }

  @override
  String importJobSuccessWithLocal(int inserted, int local) {
    return 'Imported $inserted transactions. Categorized all; $local used local rules.';
  }

  @override
  String importJobSuccessWithMisc(int inserted, int misc) {
    return 'Imported $inserted transactions. Categorized all; $misc used a best-guess category.';
  }

  @override
  String importJobSuccessCategorizedAll(int inserted) {
    return 'Imported $inserted transactions. Categorized all transactions.';
  }

  @override
  String get importJobFailedTitle => 'Import failed';

  @override
  String get importJobRetryingCategoryAssignment =>
      'Retrying category assignment...';

  @override
  String get importJobCategoryRetryCompleteProgress =>
      'Category retry complete.';

  @override
  String get importJobNoRetryableRowsSnack =>
      'No retryable category rows found.';

  @override
  String get importJobNoRetryableRowsTitle => 'No retryable rows';

  @override
  String importJobRetriedCategoriesSnack(int count) {
    return 'Retried categories. Updated $count transactions.';
  }

  @override
  String get importJobCategoryRetryCompleteTitle => 'Category retry complete';

  @override
  String get importJobCategoryRetryFailedProgress => 'Category retry failed.';

  @override
  String importJobCategoryRetryFailedSnack(String error) {
    return 'Could not retry category assignment: $error';
  }

  @override
  String get importJobCategoryRetryFailedTitle => 'Category retry failed';

  @override
  String importJobRetryFailedLine(String error) {
    return 'Retry failed: $error';
  }

  @override
  String importJobSummaryParsedLine(int parsed, int inserted, int skipped) {
    return 'Parsed $parsed; imported $inserted; skipped $skipped duplicates.';
  }

  @override
  String importJobSummaryAiLine(String status, int aiRows, int localRows) {
    return 'AI $status; AI rows $aiRows; local-rule rows $localRows.';
  }

  @override
  String importJobSummaryCategoriesLine(int misc, int failures) {
    return 'Best-guess categories $misc; category update failures $failures.';
  }

  @override
  String importJobSummaryScannedLine(int scanned, int retryable) {
    return 'Scanned $scanned; retryable $retryable.';
  }

  @override
  String importJobSummaryUpdatedLine(int updated, int remaining) {
    return 'Updated $updated; still uncategorized $remaining.';
  }

  @override
  String get importJobAiStatusCompleted => 'completed';

  @override
  String get importJobAiStatusUnavailable => 'unavailable';

  @override
  String get mfaEnrollmentAppBarTitle => 'Multi-factor authentication';

  @override
  String get mfaEnrollmentTurnOffTitle => 'Turn off MFA?';

  @override
  String get mfaEnrollmentCancel => 'Cancel';

  @override
  String get mfaEnrollmentTurnOff => 'Turn off';

  @override
  String get mfaEnrollmentAuthenticatorApps => 'Authenticator apps';

  @override
  String get mfaEnrollmentMfaOn => 'MFA is on';

  @override
  String get mfaEnrollmentMfaOff => 'MFA is off';

  @override
  String get mfaEnrollmentTurnOnMfa => 'Turn on MFA';

  @override
  String get mfaEnrollmentSetupTitle => 'Set up authenticator app';

  @override
  String get mfaEnrollmentCodeLabel => '6-digit code';

  @override
  String get mfaEnrollmentEnableMfa => 'Enable MFA';

  @override
  String get mfaVerificationTitle => 'Enter your MFA code';

  @override
  String get mfaVerificationSubtitle =>
      'Open your authenticator app and enter the current 6-digit code for Clarity.';

  @override
  String get mfaVerificationAuthenticatorAppLabel => 'Authenticator app';

  @override
  String get mfaVerificationVerifyAndContinue => 'Verify and continue';

  @override
  String get mfaEnterSixDigitCode => 'Enter the 6-digit code.';

  @override
  String get mfaEnrollmentTurnOffBodySingle =>
      'Your account will no longer ask for an authenticator code after password sign-in.';

  @override
  String mfaEnrollmentTurnOffBodyMultiple(int factorCount) {
    return 'This removes all $factorCount authenticator apps. Your account will no longer ask for an authenticator code after password sign-in.';
  }

  @override
  String get mfaEnrollmentRemoveTitle => 'Remove MFA?';

  @override
  String mfaEnrollmentRemoveBody(String factorName) {
    return 'Remove $factorName? You can enroll another authenticator app later.';
  }

  @override
  String get mfaEnrollmentAddAnotherApp => 'Add another app';

  @override
  String get mfaEnrollmentMfaOnDescription =>
      'Your account requires an authenticator code after password sign-in.';

  @override
  String get mfaEnrollmentMfaOffDescription =>
      'Add an authenticator app to protect your financial workspace.';

  @override
  String get mfaEnrollmentSetupInstructions =>
      'Scan this QR code in 1Password, Google Authenticator, Authy, or another TOTP app.';

  @override
  String get mfaEnrollmentCopyAuthenticatorUri => 'Copy authenticator URI';

  @override
  String get mfaEnrollmentManualSetupKey => 'Manual setup key';

  @override
  String get mfaEnrollmentCopyManualSetupKeyTooltip => 'Copy manual setup key';

  @override
  String get mfaEnrollmentRemoveAuthenticatorTooltip =>
      'Remove authenticator app';

  @override
  String get mfaEnrollmentRecoveryNotice =>
      'Supabase Auth does not provide recovery codes for TOTP. Add a second authenticator app as a backup before removing your only factor.';

  @override
  String get mfaEnrollmentManualSetupKeyCopyLabel => 'Manual setup key';

  @override
  String get mfaEnrollmentAuthenticatorUriCopyLabel => 'Authenticator URI';

  @override
  String get authErrorInvalidCredentials =>
      'Email or password is incorrect. Try again or create a new account.';

  @override
  String get authErrorAccountExists =>
      'An account with this email already exists. Sign in instead.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirm your email first, then sign in.';

  @override
  String get authErrorEmailSendFailed =>
      'We could not send a confirmation email right now. Try again in a few minutes or contact support if this continues.';

  @override
  String get authErrorSignupsDisabled =>
      'New account sign-up is disabled for this app right now.';

  @override
  String get authErrorWeakPassword =>
      'Choose a stronger password and try again.';

  @override
  String get authErrorMfaCodeRejected =>
      'That code was not accepted. Check your authenticator app and try again.';

  @override
  String get authErrorMfaNotEnabled =>
      'MFA is not enabled for this Supabase project.';

  @override
  String get authErrorTooManyAttempts =>
      'Too many attempts. Wait a moment, then try again.';

  @override
  String get authErrorNoAuthenticatorAvailable =>
      'No verified authenticator app is available for this account.';

  @override
  String get authErrorStartEnrollmentFirst =>
      'Start MFA enrollment before verifying a code.';

  @override
  String get authInfoAccountCreatedSignedIn =>
      'Account created. You are signed in.';

  @override
  String authInfoConfirmationLinkSent(String email) {
    return 'We sent a confirmation link to $email. Open it, then return here and sign in.';
  }

  @override
  String get authInfoEnterAuthenticatorCode =>
      'Enter your authenticator code to finish signing in.';

  @override
  String authInfoPasswordResetSent(String email) {
    return 'If an account exists for $email, we sent a password reset link.';
  }

  @override
  String get authInfoMfaEnrollmentStart =>
      'Scan the QR code, then enter the 6-digit code from your app.';

  @override
  String get authInfoMfaEnabledEmailSent =>
      'MFA is enabled. We sent you a confirmation email.';

  @override
  String get authInfoMfaEnabledEmailFailed =>
      'MFA is enabled. Confirmation email could not be sent right now.';

  @override
  String get authInfoMfaDisabledEmailSent =>
      'MFA is off. We sent you a confirmation email.';

  @override
  String get authInfoMfaDisabledEmailFailed =>
      'MFA is off. Confirmation email could not be sent right now.';

  @override
  String get authInfoSignInVerified => 'Sign-in verified.';

  @override
  String get authInfoAuthenticatorRemoved => 'Authenticator app removed.';

  @override
  String get authInfoMfaAlreadyOff => 'MFA is already off.';

  @override
  String get importProgressImporting => 'Importing...';

  @override
  String get importProgressCategorizing => 'Categorizing...';

  @override
  String get importProgressSavingCategories => 'Saving categories...';

  @override
  String get importProgressApplyingFallbackCategories =>
      'Applying fallback categories...';

  @override
  String get importProgressRefreshing => 'Refreshing...';

  @override
  String get usageChartNoDailyVoiceUsage => 'No daily voice usage yet.';

  @override
  String get usageChartNotEnoughRadarData =>
      'Not enough usage data for radar chart.';

  @override
  String get usageChartNoDailyCallData => 'No daily call data yet.';

  @override
  String get usageChartDayMon => 'Mon';

  @override
  String get usageChartDayTue => 'Tue';

  @override
  String get usageChartDayWed => 'Wed';

  @override
  String get usageChartDayThu => 'Thu';

  @override
  String get usageChartDayFri => 'Fri';

  @override
  String get usageChartDaySat => 'Sat';

  @override
  String get usageChartDaySun => 'Sun';

  @override
  String get commonNone => 'None';

  @override
  String dashboardBudgetNoBudgetsForPeriod(String periodLabel) {
    return 'No budgets set for $periodLabel yet.';
  }

  @override
  String dashboardBudgetCategoriesOnTrack(int onTrack, int budgeted) {
    return '$onTrack/$budgeted categories on track';
  }

  @override
  String dashboardBudgetTotalOverspent(String amount) {
    return 'Total overspent $amount';
  }

  @override
  String dashboardBudgetBudgetedSpentLine(String budgeted, String spent) {
    return 'Budgeted $budgeted / Spent $spent';
  }

  @override
  String get dashboardBudgetNoOverspendingCategories =>
      'No overspending categories in this period.';

  @override
  String dashboardBudgetCategoryOverspent(String label, String amount) {
    return '$label: overspent $amount';
  }

  @override
  String dashboardHealthSpendingAheadOfIncome(String amount) {
    return 'Spending is ahead of income by $amount this month.';
  }

  @override
  String dashboardHealthIncomeAheadOfSpending(String amount) {
    return 'Income is ahead of spending by $amount this month.';
  }

  @override
  String get dashboardHealthSpendingActiveNoIncome =>
      'Spending is active this month; no income is recorded in this scope.';

  @override
  String get dashboardHealthIncomeNoSpending =>
      'Income is recorded and no spending has posted for this month yet.';

  @override
  String get dashboardHealthNoCurrentMonthActivity =>
      'No current-month activity in this scope yet.';

  @override
  String get dashboardHealthConnectTransactions =>
      'Connect transactions to build account health.';

  @override
  String get dashboardHealthNoBudgets => 'No budgets';

  @override
  String get dashboardHealthSetBudgets =>
      'Set budgets to compare this month against a target.';

  @override
  String dashboardHealthCategoryOverBy(String label, String amount) {
    return '$label is over by $amount.';
  }

  @override
  String dashboardHealthBudgetControlled(String periodLabel) {
    return 'Budget coverage looks controlled for $periodLabel.';
  }

  @override
  String get dashboardHealthNoSpendingPressure =>
      'No spending pressure recorded this month.';

  @override
  String dashboardHealthTopSpendPressure(String name) {
    return '$name is the largest spend pressure this month.';
  }

  @override
  String get dashboardHealthThisMonthNet => 'This month net';

  @override
  String get dashboardHealthSpendPressureLabel => 'Spend pressure';

  @override
  String get dashboardHealthBudgetCoverageLabel => 'Budget coverage';

  @override
  String dashboardHealthIncomeSpendingLine(String income, String spending) {
    return 'Income $income / Spending $spending';
  }

  @override
  String get dashboardChartConnectAccountsCashFlow =>
      'Connect accounts to see monthly cash flow.';

  @override
  String get dashboardChartNoCategorySpending => 'No category spending yet.';

  @override
  String get dashboardChartNoSpendingPressure =>
      'No spending pressure this month.';

  @override
  String get dashboardChartNoBudgetCategories =>
      'No budget categories to chart.';

  @override
  String get dashboardChartNoSpendingHistory => 'No spending history yet.';

  @override
  String get dashboardChartNoIncomeOrSpending =>
      'No income or spending this month.';

  @override
  String dashboardChartIncomeSpendingSummary(String income, String spent) {
    return 'Income $income · Spending $spent';
  }

  @override
  String get monthDetailDeleteMonthTooltip => 'Delete this month';

  @override
  String monthDetailDeleteMonthTitle(String monthLabel) {
    return 'Delete $monthLabel transactions?';
  }

  @override
  String monthDetailDeleteMonthBody(
    int count,
    String transactionSuffix,
    String monthLabel,
  ) {
    return 'This will permanently delete the $count visible transaction$transactionSuffix for this account in $monthLabel. Other months will stay untouched.';
  }

  @override
  String get monthDetailDeleteMonthButton => 'Delete month';

  @override
  String monthDetailDeletedTransactions(
    int count,
    String monthLabel,
    String transactionSuffix,
  ) {
    return 'Deleted $count $monthLabel transaction$transactionSuffix.';
  }

  @override
  String get monthDetailNothingDeleted => 'No transactions were deleted.';

  @override
  String get monthDetailLoadingMonth => 'Loading month';

  @override
  String get monthDetailNetThisMonth => 'NET THIS MONTH';

  @override
  String get monthDetailNoTransactionsLeft =>
      'No transactions left for this month.';

  @override
  String get monthDetailDeleteTransactionTooltip => 'Delete transaction';

  @override
  String get monthDetailDeleteTransactionTitle => 'Delete this transaction?';

  @override
  String get monthDetailDeleteTransactionBody =>
      'This transaction will be permanently deleted.';

  @override
  String get monthDetailTransactionDeleted => 'Transaction deleted.';

  @override
  String get monthDetailDeleteTransactionFailed =>
      'Could not delete transaction.';

  @override
  String get monthDetailPlaidDeleteProtection =>
      'Plaid transactions sync from your bank. Use resync or disconnect instead of local deletion.';

  @override
  String get accountsScreenNoActiveConnectionRefresh =>
      'No active bank connection to refresh.';

  @override
  String get accountsScreenCouldNotRefreshAccounts =>
      'Could not refresh connected accounts.';

  @override
  String get accountsScreenDisconnectedConnection =>
      'This bank connection is disconnected.';

  @override
  String get accountsScreenCouldNotRefreshAccount =>
      'Could not refresh this account.';

  @override
  String get accountsScreenCouldNotDisconnect =>
      'Could not disconnect this bank.';

  @override
  String accountsScreenDisconnectedNotice(String institutionName) {
    return '$institutionName disconnected. Future Plaid sync is stopped.';
  }

  @override
  String get plaidAccountStatusConnected => 'Connected';

  @override
  String get plaidAccountStatusDegradedLabel => 'Degraded';

  @override
  String get plaidAccountStatusNeedsLogin => 'Needs login';

  @override
  String get plaidAccountStatusRefreshing =>
      'Refreshing this bank connection now.';

  @override
  String get plaidAccountStatusDegradedMessage =>
      'Sync needs attention. Try refresh; if it still fails, reconnect this bank in Plaid.';

  @override
  String get plaidAccountStatusLoginRequiredMessage =>
      'Plaid needs you to sign in again. Connect this bank again to resume sync.';

  @override
  String get plaidAccountStatusExpiringSoonMessage =>
      'This Plaid connection may expire soon. Refresh now or reconnect if sync stops.';

  @override
  String get plaidAccountStatusDisconnectedMessage =>
      'Future Plaid sync is stopped. Existing account history stays in Clarity.';

  @override
  String get plaidAccountNoWebhookYet =>
      'No Plaid webhook has arrived yet. Use refresh if transactions look stale.';

  @override
  String plaidAccountNoRecentWebhook(String relativeTime) {
    return 'No recent Plaid webhook. Last bank update signal was $relativeTime.';
  }

  @override
  String plaidAccountWebhookDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String plaidAccountWebhookHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String plaidAccountWebhookMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String get plaidAccountWebhookJustNow => 'just now';

  @override
  String get accountDetailNoCsvUploads =>
      'No CSV uploads found for this account.';

  @override
  String accountDetailDeleteCsvBody(int count, String transactionSuffix) {
    return 'Delete $count transaction$transactionSuffix from this upload? This cannot be undone.';
  }

  @override
  String accountDetailDeletedFromCsv(int deleted, String transactionSuffix) {
    return 'Deleted $deleted transaction$transactionSuffix from CSV upload.';
  }

  @override
  String get accountDetailCsvAlreadyDeleted =>
      'CSV upload was already deleted.';

  @override
  String get accountDetailCouldNotDeleteCsv => 'Could not delete CSV upload.';

  @override
  String get accountDetailCouldNotDeleteAccount => 'Could not delete account.';

  @override
  String accountDetailAccountDeleted(String accountName, String cleanupNote) {
    return '$accountName deleted.$cleanupNote';
  }

  @override
  String accountDetailRemovedBudgets(int count, String budgetSuffix) {
    return ' Removed $count unused budget$budgetSuffix.';
  }

  @override
  String accountDetailDeleteUnusedCategoryTitle(String plural) {
    return 'Delete unused custom $plural?';
  }

  @override
  String accountDetailDeleteUnusedCategorySingle(String name) {
    return '\"$name\" no longer has active transactions after deleting this account. Delete this custom category too?';
  }

  @override
  String accountDetailDeleteUnusedCategoryMultiple(String names) {
    return 'These custom categories no longer have active transactions after deleting this account: $names. Delete them too?';
  }

  @override
  String accountDetailUploadBatchLabel(String importId) {
    return 'Upload $importId';
  }

  @override
  String get accountDetailCategorySingular => 'category';

  @override
  String get accountDetailCategoriesPlural => 'categories';

  @override
  String get csvPreviewPlaidOverlapHint =>
      'This connected account already syncs through Plaid. Import only if this CSV covers rows Clarity does not have yet.';

  @override
  String get csvPreviewManualFallbackHint =>
      'This is a manual fallback import. You may need to upload newer CSV files later to keep this account current.';

  @override
  String get csvPreviewLayoutInferred =>
      'Column layout was inferred. Review the date range before importing.';

  @override
  String get csvPreviewDuplicateImport =>
      'This looks like a duplicate import for this account. Choose another account, or delete the previous CSV upload from the account page before retrying.';

  @override
  String get accountSelectionManualAccountForCsv =>
      'Add a manual account for this CSV';

  @override
  String get assistantTabChat => 'Chat';

  @override
  String get assistantTabKnows => 'Knows';

  @override
  String get assistantTabGoals => 'Goals';

  @override
  String get assistantTabChats => 'Chats';

  @override
  String assistantTabSemanticLabel(String tab) {
    return 'Assistant $tab tab';
  }

  @override
  String get voicePanelVoiceMuted => 'Voice muted';

  @override
  String get voicePanelVoiceReady => 'Voice ready';

  @override
  String get voicePanelListening => 'Listening';

  @override
  String get voicePanelThinking => 'Thinking';

  @override
  String get voicePanelSpeaking => 'Speaking';

  @override
  String get voicePanelVoicePaused => 'Voice paused';

  @override
  String get voiceFailureSessionReconnect =>
      'Your Clarity session needs to reconnect before voice can continue. Sign in again if this keeps happening.';

  @override
  String get voiceFailureMicrophoneAccess =>
      'Microphone access is needed for voice. Check Settings, then try again.';

  @override
  String get voiceFailureDidNotCatch =>
      'I didn\'t catch that. Tap Try again when you are ready.';

  @override
  String get voiceFailureConnectionDropped =>
      'Voice connection dropped. Tap Try again to reconnect.';

  @override
  String get voiceFailureTranscriptUnreadable =>
      'I couldn\'t read that transcript. Tap Try again and say it once more.';

  @override
  String get voiceFailurePlaybackFailed =>
      'Rex answered, but I couldn\'t play the audio. Tap Try again to hear the reply.';

  @override
  String get voiceFailurePausedDefault =>
      'Voice paused. Tap Try again when you are ready to continue.';

  @override
  String get memoryHeaderEmptyActiveBody =>
      'Ask Rex in chat or voice to save something, and it will show up here.';

  @override
  String get memoryHeaderEmptyBody =>
      'Saved facts, people, and preferences from chat or voice will appear here.';

  @override
  String get memoryHeaderNoMatchingTitle => 'No matching information';

  @override
  String get memoryHeaderNoMatchingBody => 'Try another search or filter.';

  @override
  String get memoryPagePersonUpdated => 'Person updated';

  @override
  String get memoryPageRuleUpdated => 'Rule updated';

  @override
  String get memoryPagePlanUpdated => 'Plan updated';

  @override
  String get memoryPageCommitmentUpdated => 'Commitment updated';

  @override
  String get memoryEditEditPersonTitle => 'Edit person';

  @override
  String get memoryEditEditRuleTitle => 'Edit rule';

  @override
  String get memoryEditEditPlanTitle => 'Edit plan';

  @override
  String get memoryEditEditCommitmentTitle => 'Edit commitment';

  @override
  String get memoryEditRuleTextLabel => 'Rule text';

  @override
  String get memoryEditTriggerKeywordsLabel => 'Trigger keywords';

  @override
  String get memoryEditDesiredOutcomeLabel => 'Desired outcome';

  @override
  String get memoryEditAliasesLabel => 'Aliases';

  @override
  String memoryArchiveNamedTitle(String label) {
    return 'Archive $label?';
  }

  @override
  String memoryArchiveStructuredBody(String label) {
    return 'This $label will stop being used as active context. It will remain in information history.';
  }

  @override
  String get memoryDisplayLocation => 'Location';

  @override
  String get memoryDisplayBirthday => 'Birthday';

  @override
  String get memoryDisplayJob => 'Job';

  @override
  String get memoryDisplayWorkplace => 'Workplace';

  @override
  String get memoryDisplayImportantDate => 'Important date';

  @override
  String get accountabilityAddGoalTitle => 'Add goal';

  @override
  String get accountabilityAddCommitmentTitle => 'Add commitment';

  @override
  String get accountabilityAddGoalPrimaryLabel => 'Goal title';

  @override
  String get accountabilityAddCommitmentPrimaryLabel => 'Commitment title';

  @override
  String get accountabilityAddGoalPrimaryHint =>
      'Build a reliable morning routine';

  @override
  String get accountabilityAddGoalDetailHint =>
      'Wake up at 5 AM and start the day cleanly';

  @override
  String get accountabilityAddCommitmentPrimaryHint => 'Wake up at 5 AM';

  @override
  String get accountabilityAddCommitmentDetailHint =>
      'Wake up at 5 AM and start my morning routine';

  @override
  String get accountabilityGoalSaved => 'Goal saved.';

  @override
  String get accountabilityCommitmentSaved => 'Commitment saved.';

  @override
  String get accountabilityCommitmentCompleted => 'Commitment completed.';

  @override
  String get accountabilityMarkMissedTitle => 'Mark missed?';

  @override
  String accountabilityMarkMissedBody(String title) {
    return 'Mark \"$title\" as missed? It will leave your active Goals list.';
  }

  @override
  String get accountabilityArchiveCommitmentTitle => 'Archive commitment?';

  @override
  String accountabilityArchiveCommitmentBody(String title) {
    return 'Archive \"$title\"? It will leave your active Goals list.';
  }

  @override
  String get accountabilityArchiveGoalTitle => 'Archive goal?';

  @override
  String accountabilityArchiveGoalBody(String title) {
    return 'Archive \"$title\"? It will leave your active Goals list.';
  }

  @override
  String get accountabilityCommitmentMarkedMissed =>
      'Commitment marked missed.';

  @override
  String get accountabilityCommitmentArchived => 'Commitment archived.';

  @override
  String get accountabilityGoalArchived => 'Goal archived.';

  @override
  String get accountabilityGoalUpdated => 'Goal updated.';

  @override
  String get accountabilityCommitmentUpdated => 'Commitment updated.';

  @override
  String get accountabilityUpdateFailed => 'Goals update failed.';

  @override
  String get accountabilityStatusOpen => 'Open';

  @override
  String get accountabilityStatusInProgress => 'In progress';

  @override
  String conversationListEmptyFilteredTitle(String filter) {
    return 'No chats in $filter';
  }

  @override
  String get conversationListEmptyFilteredMessage =>
      'Clear the date filter or choose a wider range.';

  @override
  String conversationListNoMatchesBody(String query, String suffix) {
    return 'No chats matched \"$query\"$suffix';
  }

  @override
  String conversationListNoMatchesSuffixInFilter(String filter) {
    return ' in $filter';
  }

  @override
  String conversationDateFilterCustomSingle(String date) {
    return '$date';
  }

  @override
  String conversationDateFilterCustomRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String usageSummaryAiCallsCount(int count) {
    return '$count AI calls';
  }

  @override
  String usageSummaryAiCallsThisMonth(int count) {
    return '$count AI calls this month';
  }

  @override
  String get usageAdminTitle => 'Usage administration';

  @override
  String get usageAdminSubtitle => 'All users · voice, chat, estimated cost';

  @override
  String get usageAdminOwnerSection => 'Owner';

  @override
  String get usageAdminPlatformThisMonth => 'Platform this month';

  @override
  String usageAdminActiveUsersSummary(
    int activeUserCount,
    String voiceMinutes,
    int aiCalls,
  ) {
    return '$activeUserCount active users · $voiceMinutes voice · $aiCalls AI calls';
  }

  @override
  String get usageAdminUsersSection => 'Users';

  @override
  String get usageAdminNoUsageThisMonth => 'No usage recorded this month yet.';

  @override
  String usageAdminUserTileSummary(
    String voiceMinutes,
    int chatCalls,
    int voiceCalls,
  ) {
    return '$voiceMinutes voice · $chatCalls chat · $voiceCalls voice calls';
  }

  @override
  String get usageAdminLoadingUserUsage => 'Loading user usage';

  @override
  String get usageAdminEstimatedCostThisMonth => 'Estimated cost this month';

  @override
  String get usageAdminUsageShape => 'Usage shape';

  @override
  String get usageAdminRadarVoiceMin => 'Voice min';

  @override
  String get usageAdminRadarChatLlm => 'Chat LLM';

  @override
  String get usageAdminRadarVoiceLlm => 'Voice LLM';

  @override
  String get usageAdminRadarSttMin => 'STT min';

  @override
  String get usageAdminRadarTtsMin => 'TTS min';

  @override
  String get usageCostNotTracked => 'Not tracked';

  @override
  String get usageMinutesLessThanOne => '<1 min';

  @override
  String usageMinutesFormat(int minutes) {
    return '$minutes min';
  }

  @override
  String get usageAdminLoadFailed => 'Could not load owner usage right now.';

  @override
  String get usageAdminUserLoadFailed => 'Could not load user usage history.';

  @override
  String get usageSummaryLoadFailed => 'Could not load usage right now.';

  @override
  String get memoryErrorSignInAgain =>
      'Please sign in again to manage saved information.';

  @override
  String get memoryErrorNoLongerAvailable =>
      'That memory is no longer available.';

  @override
  String get memoryErrorEditValidation =>
      'That memory change could not be saved. Check the fields and try again.';

  @override
  String get memoryErrorArchiveRefresh =>
      'That memory could not be archived. Refresh Memory and try again.';

  @override
  String get memoryErrorLoadRefresh =>
      'Could not load saved information. Refresh and try again.';

  @override
  String get memoryErrorLoadConnection =>
      'Could not load saved information. Check your connection and try again.';

  @override
  String get memoryErrorUpdateFailed =>
      'Could not update this memory. Please try again.';

  @override
  String get memoryErrorArchiveFailed =>
      'Could not archive this memory. Please try again.';

  @override
  String get serviceErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get serviceErrorSignInRequired =>
      'Inicia sesión de nuevo para continuar.';

  @override
  String get serviceErrorFetchGeneric =>
      'No se pudieron cargar los datos ahora.';

  @override
  String get serviceErrorCreateGeneric =>
      'No se pudieron guardar los cambios ahora.';

  @override
  String get serviceErrorUpdateGeneric => 'No se pudo actualizar ahora.';

  @override
  String get serviceErrorDeleteGeneric => 'No se pudo eliminar ahora.';

  @override
  String get serviceErrorFetchAccounts => 'No se pudieron cargar las cuentas.';

  @override
  String get serviceErrorCreateAccount => 'No se pudo crear la cuenta.';

  @override
  String get serviceErrorUpdateAccount => 'No se pudo actualizar la cuenta.';

  @override
  String get serviceErrorDeleteAccount => 'No se pudo eliminar la cuenta.';

  @override
  String get serviceErrorFetchStatementImports =>
      'No se pudieron cargar las importaciones de extractos.';

  @override
  String get serviceErrorSaveStatementImport =>
      'No se pudo guardar la importación del extracto.';

  @override
  String get serviceErrorDeleteStatementImport =>
      'No se pudo eliminar la importación del extracto.';

  @override
  String get serviceErrorFetchTransactions =>
      'No se pudieron cargar las transacciones.';

  @override
  String get serviceErrorCreateTransaction =>
      'No se pudo crear la transacción.';

  @override
  String get serviceErrorCreateTransactions =>
      'No se pudieron crear las transacciones.';

  @override
  String get serviceErrorUpdateTransaction =>
      'No se pudo actualizar la transacción.';

  @override
  String get serviceErrorUpdateTransactionCategories =>
      'No se pudieron actualizar las categorías de transacciones.';

  @override
  String get serviceErrorDeleteTransaction =>
      'No se pudo eliminar la transacción.';

  @override
  String get serviceErrorDeleteCsvImportTransactions =>
      'No se pudieron eliminar las transacciones importadas del CSV.';

  @override
  String get serviceErrorDeleteAccountTransactions =>
      'No se pudieron eliminar las transacciones de la cuenta en ese rango de fechas.';

  @override
  String get serviceErrorFetchBudgets =>
      'No se pudieron cargar los presupuestos.';

  @override
  String get serviceErrorCreateBudget => 'No se pudo crear el presupuesto.';

  @override
  String get serviceErrorUpdateBudget =>
      'No se pudo actualizar el presupuesto.';

  @override
  String get serviceErrorUpdateBudgetCategories =>
      'No se pudieron actualizar las categorías del presupuesto.';

  @override
  String get serviceErrorDeleteBudget => 'No se pudo eliminar el presupuesto.';

  @override
  String get serviceErrorFetchCategories =>
      'No se pudieron cargar las categorías.';

  @override
  String get serviceErrorCreateCategory => 'No se pudo crear la categoría.';

  @override
  String get serviceErrorUpdateCategory =>
      'No se pudo actualizar la categoría.';

  @override
  String get serviceErrorDeleteCategory => 'No se pudo eliminar la categoría.';

  @override
  String get serviceErrorFetchMerchantCategoryRules =>
      'No se pudieron cargar las reglas de categoría por comercio.';

  @override
  String get serviceErrorSaveMerchantCategoryRule =>
      'No se pudo guardar la regla de categoría por comercio.';

  @override
  String get serviceErrorUpdateMerchantCategoryRules =>
      'No se pudieron actualizar las reglas de categoría por comercio.';

  @override
  String get serviceErrorUpdateMerchantCategoryRule =>
      'No se pudo actualizar la regla de categoría por comercio.';

  @override
  String get serviceErrorDeleteMerchantCategoryRule =>
      'No se pudo eliminar la regla de categoría por comercio.';

  @override
  String get serviceErrorRecordAuditEvent =>
      'No se pudo registrar el evento de auditoría.';

  @override
  String get serviceErrorFetchAuditEvents =>
      'No se pudieron cargar los eventos de auditoría.';

  @override
  String get plaidLinkStartFailed => 'No se pudo iniciar la conexión bancaria.';

  @override
  String get plaidLinkSaveFailed => 'No se pudo guardar la conexión bancaria.';

  @override
  String get plaidLinkParseFailed =>
      'No se pudo interpretar la conexión bancaria.';

  @override
  String get plaidLinkConfigMissing =>
      'La conexión bancaria aún no está configurada.';

  @override
  String get plaidLinkCancelled => 'Se canceló la conexión bancaria.';

  @override
  String get plaidLinkGenericFailed => 'No se pudo conectar este banco ahora.';

  @override
  String get plaidAccountNoConnectedBank =>
      'No hay banco conectado para actualizar.';

  @override
  String get plaidAccountParseStatusFailed =>
      'No se pudo leer el estado de la conexión bancaria.';

  @override
  String get plaidAccountGenericFailed =>
      'No se pudo actualizar esta conexión bancaria ahora.';

  @override
  String plaidRefreshAccountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return '$_temp0';
  }

  @override
  String plaidRefreshWithTransactionUpdates(
    String accountLabel,
    int updateCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      updateCount,
      locale: localeName,
      other: '$updateCount actualizaciones de transacciones',
      one: '1 actualización de transacción',
    );
    return 'Cuentas actualizadas: $accountLabel, $_temp0.';
  }

  @override
  String plaidRefreshBalancesOnlyUnavailable(String accountLabel) {
    return 'Cuentas actualizadas: $accountLabel. Saldos actualizados. Aún no hay transacciones nuevas — Plaid sincronizará según su programación (la extracción de transacciones bajo demanda no está habilitada en este plan de Plaid).';
  }

  @override
  String plaidRefreshBalancesOnly(String accountLabel) {
    return 'Cuentas actualizadas: $accountLabel. Saldos actualizados; no hay transacciones nuevas desde la última sincronización.';
  }

  @override
  String get chatErrorNetwork =>
      'No se pudo contactar con Clarity. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get chatErrorTimeout => 'Tardó demasiado. Inténtalo de nuevo.';

  @override
  String get chatErrorUpload =>
      'No se pudo subir el adjunto. Inténtalo de nuevo.';

  @override
  String get chatErrorValidation =>
      'No se pudo enviar ese mensaje. Comprueba el adjunto e inténtalo de nuevo.';

  @override
  String get chatErrorInvalidResponse =>
      'Clarity devolvió una respuesta inesperada. Inténtalo de nuevo.';

  @override
  String get chatAttachmentTooLarge =>
      'El adjunto es demasiado grande. El tamaño máximo es 2 MB.';

  @override
  String get chatAttachmentImageTooLarge =>
      'La imagen es demasiado grande. El tamaño máximo es 5 MB.';

  @override
  String get chatAttachmentPdfTooLarge =>
      'El PDF es demasiado grande. El tamaño máximo es 10 MB.';

  @override
  String get chatAttachmentInvalidType =>
      'Adjunta un archivo .txt, .md, .csv, .pdf, .jpg, .png o .webp.';

  @override
  String get chatAttachmentUtf8Required =>
      'El adjunto debe ser texto UTF-8 válido.';

  @override
  String get chatAttachmentReadFailed =>
      'No se pudo leer el archivo seleccionado.';

  @override
  String get conversationListLoadFailed =>
      'No se pudieron cargar los chats ahora.';

  @override
  String get conversationListCreateFailed =>
      'No se pudo iniciar un chat nuevo ahora.';

  @override
  String get conversationListSearchFailed =>
      'No se pudieron buscar chats ahora.';

  @override
  String get voiceErrorAudioSessionStartFailed =>
      'No se pudo iniciar la sesión de audio de la llamada de voz.';

  @override
  String get voiceErrorPlayRexVoiceFailed =>
      'No se pudo reproducir la voz de Rex para esta respuesta.';

  @override
  String get voiceErrorStreamVoiceAudioFailed =>
      'No se pudo transmitir el audio de voz.';

  @override
  String get voiceErrorCaptureVoiceAudioFailed =>
      'No se pudo capturar el audio de voz.';

  @override
  String get voiceErrorActiveCallFailed => 'La llamada de voz activa falló.';

  @override
  String get voiceErrorNativeSessionFailed =>
      'La sesión de voz nativa de iOS falló.';

  @override
  String get voiceErrorAssistantStreamFailed =>
      'El flujo de voz del asistente falló.';

  @override
  String get voiceErrorAssistantStreamDisconnected =>
      'Se desconectó el flujo de voz del asistente. Prueba la voz de nuevo.';

  @override
  String get voiceErrorOpenAssistantStreamFailed =>
      'No se pudo abrir el flujo de voz del asistente.';

  @override
  String get voiceErrorStillDidNotHear =>
      'Todavía no escuché nada. Toca Probar de nuevo cuando estés listo para usar la voz.';

  @override
  String get voiceErrorStuckThinkingNative =>
      'Rex se quedó pensando, así que reinicié el flujo de voz nativo. Inténtalo de nuevo.';

  @override
  String get voiceErrorStuckThinking =>
      'Rex se quedó pensando, así que reinicié el flujo de voz. Inténtalo de nuevo.';

  @override
  String get voiceErrorPreviousResponseInProgress =>
      'Rex está terminando la respuesta anterior. Inténtalo de nuevo cuando termine.';

  @override
  String get voiceErrorMicPermanentlyDenied =>
      'El permiso del micrófono está bloqueado. Actívalo en Ajustes de iOS > Privacidad y seguridad > Micrófono para llamar a Rex.';

  @override
  String get voiceErrorMicRestricted =>
      'El acceso al micrófono está restringido en este dispositivo.';

  @override
  String get voiceErrorMicDenied =>
      'Se requiere permiso del micrófono para llamar a Rex. Toca Probar de nuevo para solicitar acceso, o actívalo en Ajustes de iOS > Privacidad y seguridad > Micrófono.';

  @override
  String get voiceErrorBackgroundMicRestart =>
      'El asistente no pudo reiniciar el micrófono en segundo plano. Abre el asistente para continuar.';
}
