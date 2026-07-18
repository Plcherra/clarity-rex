// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get commonArchive => 'Delete';

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
  String get commonPause => 'Pause';

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
  String get commonKeepEditing => 'Keep editing';

  @override
  String get personConfirmTitle => 'Save person';

  @override
  String get personConfirmNameLabel => 'Name';

  @override
  String get personConfirmRelationshipLabel => 'Relationship';

  @override
  String get personConfirmBirthdayLabel => 'Birthday';

  @override
  String get personConfirmNotesLabel => 'Notes';

  @override
  String get personConfirmTwoFieldsRequired => 'Add at least 2 fields to save.';

  @override
  String get personConfirmDiscardTitle => 'Discard this person card?';

  @override
  String get personConfirmDiscardBody =>
      'You typed details that haven’t been saved. Discard them?';

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
  String get commonInfo => 'Info';

  @override
  String get commonCritical => 'Critical';

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
    return '$label deleted';
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
      'Minutes today, this week, and this month on web and mobile';

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
  String get dashboardInsightsStripTitle => 'What to watch';

  @override
  String dashboardInsightsNetNegative(String amount) {
    return 'Spending exceeds income by $amount this month.';
  }

  @override
  String dashboardInsightsNetPositive(String amount) {
    return 'Net cash flow is $amount ahead this month.';
  }

  @override
  String get dashboardInsightsNetBalanced =>
      'Income and spending are balanced this month.';

  @override
  String dashboardInsightsMomLeakUp(
    String category,
    String percent,
    String amount,
  ) {
    return '$category rose $percent month-over-month ($amount).';
  }

  @override
  String dashboardInsightsMomLeakNew(String category, String amount) {
    return '$category is new spending pressure at $amount this month.';
  }

  @override
  String dashboardInsightsBudgetOver(String category, String amount) {
    return '$category is over budget by $amount.';
  }

  @override
  String get dashboardInsightsSeeChart => 'See chart';

  @override
  String get insightsSeeAll => 'See all';

  @override
  String get insightsFeedTitle => 'Insights';

  @override
  String get insightsOpenTooltip => 'Insights';

  @override
  String get insightsCurrentSection => 'What needs attention';

  @override
  String get insightsSavedSection => 'Saved alerts';

  @override
  String get insightsFeedEmpty =>
      'No current signals right now. Check back after new spending or budget activity.';

  @override
  String get insightsSavedEmpty =>
      'No saved alerts yet. Turn on proactive insights in Profile to keep alerts over time.';

  @override
  String get insightsOptInRequired =>
      'Optional: turn on proactive insights in Profile to save alerts over time.';

  @override
  String get insightsReviewDashboard => 'Review on Dashboard';

  @override
  String get insightsTypeSpendingPressure => 'Spending pressure';

  @override
  String get insightsTypeBudgetOver => 'Over budget';

  @override
  String get insightsTypeCashFlow => 'Cash flow';

  @override
  String get insightsTypeAccountability => 'Goals & habits';

  @override
  String get insightsGuidanceSpendingPressure =>
      'This category is driving unusual spend. Review recent transactions and decide whether to cut back or set a clearer budget.';

  @override
  String get insightsGuidanceBudgetOver =>
      'This budget is already over. Adjust the limit if the spend is intentional, or pause related purchases until the period resets.';

  @override
  String get insightsGuidanceCashFlow =>
      'Net cash flow needs a closer look this month. Compare income and spending before new commitments.';

  @override
  String get insightsGuidanceAccountability =>
      'A goal or open thread needs a check-in. Open Goals to update progress or adjust the plan.';

  @override
  String get insightsSourceDashboard => 'From your dashboard';

  @override
  String get insightsSourceAccountability => 'From goals & accountability';

  @override
  String get insightsStorageUnavailable =>
      'Saved insights storage is not available yet. Live signals above still work from your dashboard data.';

  @override
  String get insightsApiUnreadableError =>
      'Backend returned an unreadable error.';

  @override
  String get insightsApiGenericError => 'Clarity API returned an error.';

  @override
  String get insightsApiInvalidListResponse =>
      'Invalid insights list response.';

  @override
  String get insightsApiInvalidListPayload => 'Invalid insights list payload.';

  @override
  String get insightsApiInvalidSyncResponse =>
      'Invalid insights sync response.';

  @override
  String get insightsApiInvalidMarkReadResponse =>
      'Invalid mark-read response.';

  @override
  String get profileProactiveInsightsTitle => 'Proactive financial insights';

  @override
  String get profileProactiveInsightsSubtitle =>
      'Save deterministic alerts when your data changes. No background monitoring runs until you turn this on.';

  @override
  String get assistantCompanionSettingsTitle => 'Companion saves';

  @override
  String get assistantCompanionSettingsSubtitle =>
      'Choose how Rex suggests goals, open threads, and memory during chat. Saves always show a confirm card before anything is stored.';

  @override
  String get assistantCompanionSettingsGearLabel => 'Companion save settings';

  @override
  String get assistantCompanionSettingsTabLabel => 'Saves';

  @override
  String get assistantAutoProposalsModeLabel => 'Auto suggestions';

  @override
  String get assistantAutoProposalsModeOff => 'Off';

  @override
  String get assistantAutoProposalsModeText => 'Text only';

  @override
  String get assistantAutoProposalsModeCard => 'Confirm card';

  @override
  String get assistantAutoProposalsModeTextHint =>
      'Rex still shows a confirm card; replies also mention the pending save in chat.';

  @override
  String get assistantAutoProposalsModeCardHint =>
      'Rex shows an editable confirm card before saving.';

  @override
  String get assistantAutoProposalsTypeThreads =>
      'Open threads (habits & check-ins)';

  @override
  String get assistantAutoProposalsTypeGoals => 'Goals (things to achieve)';

  @override
  String get assistantAutoProposalsTypeMemory => 'Memory (facts & preferences)';

  @override
  String get assistantFinanceEditsEnabledLabel => 'Allow Rex to edit finances';

  @override
  String get assistantFinanceEditsEnabledSubtitle =>
      'When off, Rex can advise but won\'t propose transaction or budget changes.';

  @override
  String get chatShowMore => 'Show more';

  @override
  String get chatShowLess => 'Show less';

  @override
  String get dashboardChartCategorySpendSubtitle => 'This month total';

  @override
  String get dashboardChartSpendingPressureSubtitle =>
      'Month-over-month pressure';

  @override
  String get dashboardSectionCoreCharts => 'Core charts';

  @override
  String get dashboardSectionTrendCharts => 'Trends';

  @override
  String get dashboardSectionTrendChartsHint =>
      'Income mix and six-month history';

  @override
  String get dashboardSectionSpendingAnalysis => 'Spending analysis';

  @override
  String get dashboardSectionSpendingAnalysisHint =>
      'Categories rising vs last month';

  @override
  String get dashboardTransactionsSectionTitle => 'Transactions';

  @override
  String get transactionsMiniAnalyticsTitle => 'This month at a glance';

  @override
  String get transactionsMiniAnalyticsSubtitle =>
      'Same totals as Dashboard for the current month';

  @override
  String get transactionsMiniAnalyticsSpent => 'Spent';

  @override
  String get transactionsMiniAnalyticsIncome => 'Income';

  @override
  String get transactionsMiniAnalyticsNet => 'Net';

  @override
  String get transactionsMiniAnalyticsTrend => 'Six-month spend trend';

  @override
  String get transactionsMiniAnalyticsTopCategories => 'Top categories';

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
  String get csvImportMobileOnlyMessage =>
      'Import CSV is available in the mobile app for now.';

  @override
  String get plaidConnectWebUnavailableMessage =>
      'Bank connect isn\'t available on this device. Use the iOS or Android app to link accounts.';

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
  String get chatInputAttachWebTooltip => 'Attach a file';

  @override
  String get chatInputStartVoiceModeTooltip => 'Start voice mode';

  @override
  String get chatInputVoiceWebTooltip =>
      'Start browser voice (keep this tab open)';

  @override
  String get voiceWebUnavailableMessage =>
      'Voice isn\'t available here. Use chat, or open Clarity on iOS or Android.';

  @override
  String get voiceWebForegroundOnlyHint => 'Browser voice — keep this tab open';

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
  String get rexViewOnDashboard => 'View on Dashboard';

  @override
  String get rexRefreshAccounts => 'Refresh accounts';

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
  String voicePanelThinkingElapsed(String elapsed) {
    return 'Thinking · $elapsed';
  }

  @override
  String voicePanelThoughtFor(String elapsed) {
    return 'Thought for $elapsed';
  }

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
  String get conversationListRenameTitle => 'Rename chat';

  @override
  String get conversationListRenameHint => 'Chat name';

  @override
  String get conversationListRenameFailed => 'Could not rename chat.';

  @override
  String get conversationListRenamedSnackBar => 'Chat renamed';

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
  String get memoryPageMemoryArchived => 'Memory deleted';

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
  String get memoryOverviewTruncated =>
      'Showing the first 50 saved items in each category. Pull to refresh for the latest information.';

  @override
  String get memoryGroupFacts => 'Facts';

  @override
  String get memoryGroupPreferences => 'Preferences';

  @override
  String get memoryGroupPeople => 'People';

  @override
  String get memoryGroupPlaces => 'Places';

  @override
  String get memoryGroupGoals => 'Goals';

  @override
  String get memoryGroupRules => 'Rules';

  @override
  String get memoryGroupEvents => 'Events';

  @override
  String get memoryGroupOther => 'Other';

  @override
  String get memoryTypeFact => 'Fact';

  @override
  String get memoryTypePreference => 'Preference';

  @override
  String get memoryTypeEvent => 'Event';

  @override
  String get memoryTypeOther => 'Other memory';

  @override
  String get memoryEntityTypePlace => 'Place';

  @override
  String get memoryEntityTypeOrganization => 'Organization';

  @override
  String get memoryEditEditEntityTitle => 'Edit saved item';

  @override
  String get memoryPageEntityUpdated => 'Saved item updated';

  @override
  String get memoryOverviewLoadMore => 'Load more';

  @override
  String get memoryOverviewTruncatedMax =>
      'Showing the first 100 saved items in each category.';

  @override
  String get memoryRecordLongTermMemory => 'Memory note';

  @override
  String get memoryRecordMemoryUpdate => 'Memory update';

  @override
  String get memoryRecordEntity => 'Person / place';

  @override
  String get memoryRecordEntityEvent => 'Related event';

  @override
  String get memoryRecordPersonalRule => 'Rule';

  @override
  String get memoryRecordPlan => 'Plan';

  @override
  String get memoryRecordPlanMilestone => 'Milestone';

  @override
  String get memoryRecordCorrection => 'Correction';

  @override
  String get memoryRecordArchive => 'Delete';

  @override
  String get memoryRecordMerge => 'Merge';

  @override
  String get memoryRecordGentleDirect => 'Gentle reminder';

  @override
  String get memoryRecordCheckpoint => 'Checkpoint';

  @override
  String get memoryRecordApproved => 'Approved';

  @override
  String get memoryRecordApplied => 'Saved';

  @override
  String get memoryRecordRejected => 'Rejected';

  @override
  String get memoryRecordFailed => 'Needs attention';

  @override
  String get memoryRecordSkipped => 'Skipped';

  @override
  String get memoryRecordActive => 'Active';

  @override
  String get memoryRecordInactive => 'Inactive';

  @override
  String get memoryRecordOpen => 'Open';

  @override
  String get memoryRecordCompleted => 'Completed';

  @override
  String get memoryRecordResolved => 'Resolved';

  @override
  String get memoryRecordDismissed => 'Dismissed';

  @override
  String get memoryRecordArchived => 'Deleted';

  @override
  String get memoryRecordLowRisk => 'Low risk';

  @override
  String get memoryRecordMediumRisk => 'Medium risk';

  @override
  String get memoryRecordHighRisk => 'High risk';

  @override
  String get memoryRecordCriticalRisk => 'Critical risk';

  @override
  String get memoryRecordInfo => 'Info';

  @override
  String get memoryRecordEventNote => 'Note';

  @override
  String get memoryRecordEventInteraction => 'Interaction';

  @override
  String get memoryRecordEventRelationshipUpdate => 'Relationship update';

  @override
  String get memoryRecordEventConflict => 'Conflict';

  @override
  String get memoryRecordEventMilestone => 'Milestone';

  @override
  String get memoryRecordProject => 'Project';

  @override
  String get memoryRecordTask => 'Task';

  @override
  String get memoryHeaderLoading => 'Loading memory';

  @override
  String get memoryHeaderEmptyActiveTitle => 'Clarity is still learning';

  @override
  String get memoryHeaderEmptyTitle => 'No saved information yet';

  @override
  String get memoryArchiveTitle => 'Delete saved information?';

  @override
  String get memoryArchiveBody =>
      'Remove this from Knows? Rex will stop using it in future conversations.';

  @override
  String get memoryTileActionsTooltip => 'Memory actions';

  @override
  String get memoryTileQuickEdit => 'Quick edit';

  @override
  String get memoryTileAddMilestone => 'Add milestone';

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
  String get accountabilitySharedAddOpenThread => 'Add open thread';

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
  String get accountabilitySectionsOpenThreads => 'Open Threads';

  @override
  String get accountabilitySectionsNoOpenThreads => 'No open threads yet.';

  @override
  String get accountabilitySectionsNeedsAttention => 'Needs attention';

  @override
  String get accountabilitySectionsNoSignals =>
      'Nothing needs attention right now.';

  @override
  String get accountabilitySectionsRuleRisks => 'Rule risks';

  @override
  String get accountabilitySectionsNoRuleRisks => 'No rule risks detected.';

  @override
  String get accountabilitySectionsRecentPatterns => 'Recent patterns';

  @override
  String get accountabilitySectionsNoRecentPatterns =>
      'No recent patterns to review.';

  @override
  String get accountabilityTilesGoalActionsTooltip => 'Goal actions';

  @override
  String get accountabilityTilesOpenThreadActionsTooltip =>
      'Open thread actions';

  @override
  String get accountabilityTilesOpenThreadDefaultSubtitle =>
      'Companion follow-up — not saved memory';

  @override
  String get accountabilityTilesMarkMissed => 'Mark missed';

  @override
  String get accountabilityDetailGoalDetails => 'Goal details';

  @override
  String get accountabilityDetailEditOpenThread => 'Edit open thread';

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
  String get dashboardHealthBurnRunwayLabel => 'Cash runway';

  @override
  String dashboardHealthBurnRunwayDays(int days) {
    return '$days days';
  }

  @override
  String dashboardHealthBurnRunwayDetail(int days) {
    return 'At this month\'s spending pace, your balance lasts about $days days.';
  }

  @override
  String get dashboardOverviewBudgetVsSpentChart => 'Budget vs spent';

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
  String get assistantTabOverview => 'Overview';

  @override
  String get assistantTabChats => 'Chats';

  @override
  String get assistantOverviewTitle => 'Companion overview';

  @override
  String get assistantOverviewSubtitle =>
      'Rules, patterns, open threads, and goals Rex is tracking with you.';

  @override
  String get assistantOverviewBrowseChats => 'Browse chats';

  @override
  String get assistantChatSidebarHideTooltip => 'Hide chats';

  @override
  String get assistantChatSidebarShowTooltip => 'Show chats';

  @override
  String get assistantOverviewAttentionTitle => 'What to watch';

  @override
  String get assistantOverviewAttentionEmpty =>
      'Nothing needs attention right now.';

  @override
  String get assistantOverviewRulesTitle => 'Active rules';

  @override
  String get assistantOverviewRulesEmpty =>
      'No active rules yet. Save one in Knows or ask Rex.';

  @override
  String get assistantOverviewThreadsTitle => 'Open threads';

  @override
  String get assistantOverviewThreadsEmpty =>
      'No open threads. Habits and check-ins will show here.';

  @override
  String get assistantOverviewGoalsTitle => 'Active goals';

  @override
  String get assistantOverviewGoalsEmpty =>
      'No active goals yet. Add one in Goals or ask Rex.';

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
  String get voiceSessionReturnToChat => 'Return to Assistant chat';

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
      'Add something here, or ask Rex in chat or voice to save it.';

  @override
  String get memoryHeaderEmptyBody =>
      'Saved facts, people, and preferences will appear here.';

  @override
  String get memoryHeaderEmptyAddAction => 'Add saved information';

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
  String get memoryCreateAddTooltip => 'Add saved information';

  @override
  String get memoryCreateChooseType => 'What should Clarity remember?';

  @override
  String get memoryCreateFact => 'Fact';

  @override
  String get memoryCreatePreference => 'Preference';

  @override
  String get memoryCreateRule => 'Rule';

  @override
  String get memoryCreatePlan => 'Plan';

  @override
  String get memoryCreateFactTitle => 'Add a fact';

  @override
  String get memoryCreatePreferenceTitle => 'Add a preference';

  @override
  String get memoryCreatePersonTitle => 'Add a person';

  @override
  String get memoryCreateRuleTitle => 'Add a rule';

  @override
  String get memoryCreatePlanTitle => 'Add a plan';

  @override
  String get memoryCreateCategoryLabel => 'Category';

  @override
  String get memoryCreateRelationshipLabel => 'Relationship';

  @override
  String get memoryCreateSave => 'Save to Knows';

  @override
  String get memoryPageMemoryCreated => 'Saved to Knows';

  @override
  String get memoryPagePersonCreated => 'Person saved';

  @override
  String get memoryPageRuleCreated => 'Rule saved';

  @override
  String get memoryPagePlanCreated => 'Plan saved';

  @override
  String get memoryPageMilestoneCreated => 'Milestone saved';

  @override
  String get memoryPageMilestoneUpdated => 'Milestone updated';

  @override
  String get memoryCreateMilestoneTitle => 'Add a milestone';

  @override
  String get memoryEditEditMilestoneTitle => 'Edit milestone';

  @override
  String get memoryEditEditPersonTitle => 'Edit person';

  @override
  String get memoryEditPersonRelationshipHint =>
      'Relationship — e.g. friend, coworker, sister';

  @override
  String get memoryEditPersonRelationshipHelper =>
      'Clarity uses this as the relationship type.';

  @override
  String get memoryEditPersonBirthdayHint => 'mm/dd/yyyy';

  @override
  String memoryEditPersonDeleteBody(String name) {
    return 'Remove $name from Knows? This archives the person card.';
  }

  @override
  String get memoryEditEditRuleTitle => 'Edit rule';

  @override
  String get memoryEditEditPlanTitle => 'Edit plan';

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
    return 'Delete $label?';
  }

  @override
  String memoryArchiveStructuredBody(String label) {
    return 'Remove this $label from Knows? Rex will stop using it as active context.';
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
  String get accountabilityAddOpenThreadTitle => 'Add open thread';

  @override
  String get accountabilityAddGoalPrimaryLabel => 'Goal title';

  @override
  String get accountabilityAddOpenThreadPrimaryLabel => 'Open thread title';

  @override
  String get accountabilityAddGoalPrimaryHint =>
      'Build a reliable morning routine';

  @override
  String get accountabilityAddGoalDetailHint =>
      'Wake up at 5 AM and start the day cleanly';

  @override
  String get accountabilityAddOpenThreadPrimaryHint => 'Wake up at 5 AM';

  @override
  String get accountabilityAddOpenThreadDetailHint =>
      'Wake up at 5 AM and start my morning routine';

  @override
  String get accountabilityGoalSaved => 'Goal saved.';

  @override
  String get accountabilityOpenThreadSaved => 'Open thread saved.';

  @override
  String accountabilityOpenThreadMaxActive(int count) {
    return 'You can have at most $count active open threads. Close or pause one before adding another.';
  }

  @override
  String get accountabilityOpenThreadCompleted => 'Open thread completed.';

  @override
  String get accountabilityMarkMissedTitle => 'Mark missed?';

  @override
  String accountabilityMarkMissedBody(String title) {
    return 'Mark \"$title\" as missed? It will leave your active Goals list.';
  }

  @override
  String get accountabilityArchiveOpenThreadTitle => 'Delete open thread?';

  @override
  String accountabilityArchiveOpenThreadBody(String title) {
    return 'Delete \"$title\"? It will leave your active Goals list.';
  }

  @override
  String get accountabilityArchiveGoalTitle => 'Delete goal?';

  @override
  String accountabilityArchiveGoalBody(String title) {
    return 'Delete \"$title\"? It will leave your active Goals list.';
  }

  @override
  String get accountabilityOpenThreadMarkedMissed =>
      'Open thread marked missed.';

  @override
  String get accountabilityOpenThreadArchived => 'Open thread deleted.';

  @override
  String get accountabilityGoalArchived => 'Goal deleted.';

  @override
  String get accountabilityGoalUpdated => 'Goal updated.';

  @override
  String get accountabilityOpenThreadUpdated => 'Open thread updated.';

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
  String get usageAdminPlatformAllTime => 'Platform all time';

  @override
  String usageAdminPlatformYear(int year) {
    return 'Platform $year';
  }

  @override
  String usageAdminPlatformMonth(String monthLabel) {
    return 'Platform $monthLabel';
  }

  @override
  String usageAdminPlatformDay(String dayLabel) {
    return 'Platform $dayLabel';
  }

  @override
  String get usageAdminFilterTitle => 'Period';

  @override
  String get usageAdminFilterAll => 'All';

  @override
  String get usageAdminFilterYear => 'Year';

  @override
  String get usageAdminFilterMonth => 'Month';

  @override
  String get usageAdminFilterDay => 'Day';

  @override
  String usageAdminFilterRangeLabel(
    String periodLabel,
    String startDate,
    String endDate,
  ) {
    return '$periodLabel · $startDate – $endDate';
  }

  @override
  String usageAdminAccountsSummary(
    int registeredCount,
    int activeCount,
    String voiceMinutes,
    int aiCalls,
  ) {
    return '$registeredCount accounts · $activeCount with usage · $voiceMinutes voice · $aiCalls AI calls';
  }

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
  String get usageAdminNoRegisteredUsers => 'No registered users yet.';

  @override
  String get usageAdminNoUsageInPeriod => 'No usage recorded in this period.';

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
  String get usageAdminEstimatedCostPeriod => 'Estimated cost in period';

  @override
  String get usageAdminUsageShape => 'Usage shape';

  @override
  String get usageAdminDailyChartsCaption =>
      'Daily totals for the loaded date range';

  @override
  String get usageAdminRadarChartCaption => 'Month-to-date totals (not daily)';

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
      'That memory could not be deleted. Refresh Memory and try again.';

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
      'Could not delete this memory. Please try again.';

  @override
  String get memoryErrorCreateValidation =>
      'That memory could not be saved. Check the fields and try again.';

  @override
  String get memoryErrorCreateFailed =>
      'Could not save this memory. Please try again.';

  @override
  String get serviceErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get serviceErrorSignInRequired => 'Please sign in again to continue.';

  @override
  String get serviceErrorFetchGeneric => 'Could not load data right now.';

  @override
  String get serviceErrorCreateGeneric => 'Could not save changes right now.';

  @override
  String get serviceErrorUpdateGeneric => 'Could not update right now.';

  @override
  String get serviceErrorDeleteGeneric => 'Could not delete right now.';

  @override
  String get serviceErrorFetchAccounts => 'Could not load accounts.';

  @override
  String get serviceErrorCreateAccount => 'Could not create account.';

  @override
  String get serviceErrorUpdateAccount => 'Could not update account.';

  @override
  String get serviceErrorDeleteAccount => 'Could not delete account.';

  @override
  String get serviceErrorFetchStatementImports =>
      'Could not load statement imports.';

  @override
  String get serviceErrorSaveStatementImport =>
      'Could not save statement import.';

  @override
  String get serviceErrorDeleteStatementImport =>
      'Could not delete statement import.';

  @override
  String get serviceErrorFetchTransactions => 'Could not load transactions.';

  @override
  String get serviceErrorCreateTransaction => 'Could not create transaction.';

  @override
  String get serviceErrorCreateTransactions => 'Could not create transactions.';

  @override
  String get serviceErrorUpdateTransaction => 'Could not update transaction.';

  @override
  String get serviceErrorUpdateTransactionCategories =>
      'Could not update transaction categories.';

  @override
  String get serviceErrorDeleteTransaction => 'Could not delete transaction.';

  @override
  String get serviceErrorDeleteCsvImportTransactions =>
      'Could not delete CSV import transactions.';

  @override
  String get serviceErrorDeleteAccountTransactions =>
      'Could not delete account transactions for that date range.';

  @override
  String get serviceErrorFetchBudgets => 'Could not load budgets.';

  @override
  String get serviceErrorCreateBudget => 'Could not create budget.';

  @override
  String get serviceErrorUpdateBudget => 'Could not update budget.';

  @override
  String get serviceErrorUpdateBudgetCategories =>
      'Could not update budget categories.';

  @override
  String get serviceErrorDeleteBudget => 'Could not delete budget.';

  @override
  String get serviceErrorFetchCategories => 'Could not load categories.';

  @override
  String get serviceErrorCreateCategory => 'Could not create category.';

  @override
  String get serviceErrorUpdateCategory => 'Could not update category.';

  @override
  String get serviceErrorDeleteCategory => 'Could not delete category.';

  @override
  String get serviceErrorFetchMerchantCategoryRules =>
      'Could not load merchant category rules.';

  @override
  String get serviceErrorSaveMerchantCategoryRule =>
      'Could not save merchant category rule.';

  @override
  String get serviceErrorUpdateMerchantCategoryRules =>
      'Could not update merchant category rules.';

  @override
  String get serviceErrorUpdateMerchantCategoryRule =>
      'Could not update merchant category rule.';

  @override
  String get serviceErrorDeleteMerchantCategoryRule =>
      'Could not delete merchant category rule.';

  @override
  String get serviceErrorRecordAuditEvent => 'Could not record audit event.';

  @override
  String get serviceErrorFetchAuditEvents => 'Could not load audit events.';

  @override
  String get plaidLinkStartFailed => 'Could not start bank connection.';

  @override
  String get plaidLinkSaveFailed => 'Could not save bank connection.';

  @override
  String get plaidLinkParseFailed => 'Could not parse bank connection.';

  @override
  String get plaidLinkConfigMissing => 'Bank connection is not configured yet.';

  @override
  String get plaidLinkCancelled => 'Bank connection was cancelled.';

  @override
  String get plaidLinkOpenFailed =>
      'Could not open bank connection in this browser. Refresh the page and try again.';

  @override
  String get plaidLinkGenericFailed => 'Could not connect this bank right now.';

  @override
  String get plaidAccountNoConnectedBank => 'No connected bank to refresh.';

  @override
  String get plaidAccountParseStatusFailed =>
      'Could not read bank connection status.';

  @override
  String get plaidAccountGenericFailed =>
      'Could not update this bank connection right now.';

  @override
  String plaidRefreshAccountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
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
      other: '$updateCount transaction updates',
      one: '1 transaction update',
    );
    return 'Accounts refreshed: $accountLabel, $_temp0.';
  }

  @override
  String plaidRefreshBalancesOnlyUnavailable(String accountLabel) {
    return 'Accounts refreshed: $accountLabel. Balances updated. No new transactions yet — Plaid will sync on its schedule (on-demand transaction pull is not enabled on this Plaid plan).';
  }

  @override
  String plaidRefreshBalancesOnly(String accountLabel) {
    return 'Accounts refreshed: $accountLabel. Balances updated; no new transactions since last sync.';
  }

  @override
  String get chatErrorNetwork =>
      'Could not reach Clarity. Check your connection and try again.';

  @override
  String get chatErrorTimeout => 'That took too long. Try again.';

  @override
  String get chatErrorUpload => 'Could not upload that attachment. Try again.';

  @override
  String get chatErrorValidation =>
      'That message could not be sent. Check the attachment and try again.';

  @override
  String get chatErrorInvalidResponse =>
      'Clarity returned an unexpected response. Try again.';

  @override
  String get chatPendingWriteHydrationFailed =>
      'Could not reload a pending save confirmation. Pull to refresh or reopen this chat.';

  @override
  String get chatConfirmWriteFailed =>
      'Could not confirm the save. Tap Retry to try again.';

  @override
  String get chatAttachmentTooLarge =>
      'Attachment is too large. Maximum size is 2MB.';

  @override
  String get chatAttachmentImageTooLarge =>
      'Image is too large. Maximum size is 5MB.';

  @override
  String get chatAttachmentPdfTooLarge =>
      'PDF is too large. Maximum size is 10MB.';

  @override
  String get chatAttachmentInvalidType =>
      'Attach a .txt, .md, .csv, .pdf, .jpg, .png, or .webp file.';

  @override
  String get chatAttachmentUtf8Required =>
      'Attachment must be valid UTF-8 text.';

  @override
  String get chatAttachmentReadFailed => 'Could not read selected file.';

  @override
  String get conversationListLoadFailed => 'Could not load chats right now.';

  @override
  String get conversationListCreateFailed =>
      'Could not start a new chat right now.';

  @override
  String get conversationListSearchFailed =>
      'Could not search chats right now.';

  @override
  String get voiceErrorAudioSessionStartFailed =>
      'Could not start the voice call audio session.';

  @override
  String get voiceErrorPlayRexVoiceFailed =>
      'Could not play Rex voice for this reply.';

  @override
  String get voiceErrorStreamVoiceAudioFailed =>
      'Could not stream voice audio.';

  @override
  String get voiceErrorCaptureVoiceAudioFailed =>
      'Could not capture voice audio.';

  @override
  String get voiceErrorActiveCallFailed => 'Active voice call failed.';

  @override
  String get voiceErrorNativeSessionFailed =>
      'Native iOS voice session failed.';

  @override
  String get voiceErrorAssistantStreamFailed =>
      'Assistant voice stream failed.';

  @override
  String get voiceErrorAssistantStreamDisconnected =>
      'Assistant voice stream disconnected. Try voice again.';

  @override
  String get voiceErrorOpenAssistantStreamFailed =>
      'Could not open Assistant voice stream.';

  @override
  String get voiceErrorStillDidNotHear =>
      'I still did not hear anything. Tap Try again when you are ready to use voice.';

  @override
  String get voiceErrorStuckThinkingNative =>
      'Rex got stuck thinking, so I reset the native voice stream. Try again.';

  @override
  String get voiceErrorStuckThinking =>
      'Rex got stuck thinking, so I reset the voice stream. Try again.';

  @override
  String get voiceErrorPreviousResponseInProgress =>
      'Rex is finishing the previous response. Try again after it finishes.';

  @override
  String get voiceErrorMicPermanentlyDenied =>
      'Microphone permission is blocked. Enable it in iOS Settings > Privacy & Security > Microphone to call Rex.';

  @override
  String get voiceErrorMicPermanentlyDeniedWeb =>
      'Microphone access is blocked for this site. Open your browser site settings, allow the microphone for Clarity, then try again.';

  @override
  String get voiceErrorMicRestricted =>
      'Microphone access is restricted on this device.';

  @override
  String get voiceErrorMicDenied =>
      'Microphone permission is required to call Rex. Tap Try again to prompt access, or enable it in iOS Settings > Privacy & Security > Microphone.';

  @override
  String get voiceErrorMicDeniedWeb =>
      'Microphone permission is required to call Rex. Click Try again and allow microphone access when your browser prompts you.';

  @override
  String get voiceErrorMicInsecureContext =>
      'Voice needs a secure connection. Open Clarity with https:// instead of http://.';

  @override
  String get voiceErrorMicBrowserSettings =>
      'Allow the microphone for Clarity in your browser site settings (lock icon in the address bar), then tap Try again.';

  @override
  String get voiceErrorBackgroundMicRestart =>
      'Assistant could not restart the microphone in the background. Open Assistant to continue.';
}
