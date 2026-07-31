import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get navBudgets;

  /// No description provided for @navAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get navAssistant;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @loadingClarity.
  ///
  /// In en, this message translates to:
  /// **'Loading Clarity'**
  String get loadingClarity;

  /// No description provided for @startingClarity.
  ///
  /// In en, this message translates to:
  /// **'Starting Clarity'**
  String get startingClarity;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Clarity'**
  String get authSignInTitle;

  /// No description provided for @authSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authSignUpTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your email and password to continue.'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use email and password to start your local finance workspace.'**
  String get authSignUpSubtitle;

  /// No description provided for @authFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullNameLabel;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountButton;

  /// No description provided for @authSwitchToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authSwitchToSignIn;

  /// No description provided for @authSwitchToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Create one'**
  String get authSwitchToSignUp;

  /// No description provided for @authEnterEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get authEnterEmailPassword;

  /// No description provided for @authEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name to create a profile.'**
  String get authEnterName;

  /// No description provided for @authEnterEmailForReset.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset your password.'**
  String get authEnterEmailForReset;

  /// No description provided for @authLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get authLanguageLabel;

  /// No description provided for @authConfirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get authConfirmEmailTitle;

  /// No description provided for @authConfirmEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it on this phone — Clarity should reopen and continue automatically.'**
  String authConfirmEmailSubtitle(String email);

  /// No description provided for @authConfirmEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Check spam or promotions if you do not see it within a few minutes.'**
  String get authConfirmEmailHint;

  /// No description provided for @authConfirmEmailResendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get authConfirmEmailResendButton;

  /// No description provided for @authConfirmEmailContinueButton.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed — continue'**
  String get authConfirmEmailContinueButton;

  /// No description provided for @authConfirmEmailStillPending.
  ///
  /// In en, this message translates to:
  /// **'Email is not confirmed yet. Open the link from your inbox, then return here.'**
  String get authConfirmEmailStillPending;

  /// No description provided for @authConfirmEmailResent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent again to {email}.'**
  String authConfirmEmailResent(String email);

  /// No description provided for @authConfirmEmailBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authConfirmEmailBackToSignIn;

  /// No description provided for @authInfoEmailConfirmedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed. Sign in with your password to continue.'**
  String get authInfoEmailConfirmedSignIn;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language set to {language}.'**
  String profileLanguageUpdated(String language);

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @importUploadingTransactions.
  ///
  /// In en, this message translates to:
  /// **'Uploading transactions...'**
  String get importUploadingTransactions;

  /// No description provided for @chatActionDoneSingle.
  ///
  /// In en, this message translates to:
  /// **'Done. I applied the {action} change.'**
  String chatActionDoneSingle(String action);

  /// No description provided for @chatActionDoneForSubject.
  ///
  /// In en, this message translates to:
  /// **'Done. I applied the {action} change for {subject}.'**
  String chatActionDoneForSubject(String action, String subject);

  /// No description provided for @chatActionDoneMultiple.
  ///
  /// In en, this message translates to:
  /// **'Done. I applied the {action} change to {count} records.'**
  String chatActionDoneMultiple(String action, int count);

  /// No description provided for @chatActionDoneMultipleOne.
  ///
  /// In en, this message translates to:
  /// **'Done. I applied the {action} change to 1 record.'**
  String chatActionDoneMultipleOne(String action);

  /// No description provided for @chatActionMatchedNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched, so the {action} change did not touch any records.'**
  String chatActionMatchedNothing(String action);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonArchive.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonArchive;

  /// No description provided for @commonMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get commonMerge;

  /// No description provided for @commonEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// No description provided for @commonDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get commonDisable;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get commonKeep;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get commonIncome;

  /// No description provided for @commonSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get commonSpending;

  /// No description provided for @commonNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get commonNet;

  /// No description provided for @commonUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get commonUnavailable;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get commonKeepEditing;

  /// No description provided for @personConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Save person'**
  String get personConfirmTitle;

  /// No description provided for @personConfirmNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personConfirmNameLabel;

  /// No description provided for @personConfirmRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get personConfirmRelationshipLabel;

  /// No description provided for @personConfirmBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get personConfirmBirthdayLabel;

  /// No description provided for @personConfirmNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get personConfirmNotesLabel;

  /// No description provided for @personConfirmTwoFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least 2 fields to save.'**
  String get personConfirmTwoFieldsRequired;

  /// No description provided for @personConfirmDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this person card?'**
  String get personConfirmDiscardTitle;

  /// No description provided for @personConfirmDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'You typed details that haven’t been saved. Discard them?'**
  String get personConfirmDiscardBody;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get commonThisWeek;

  /// No description provided for @commonThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get commonThisMonth;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get commonCustom;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get commonPriority;

  /// No description provided for @commonImportance.
  ///
  /// In en, this message translates to:
  /// **'Importance'**
  String get commonImportance;

  /// No description provided for @commonSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get commonSummary;

  /// No description provided for @commonNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// No description provided for @commonType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commonType;

  /// No description provided for @commonLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get commonLow;

  /// No description provided for @commonNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get commonNormal;

  /// No description provided for @commonMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get commonMedium;

  /// No description provided for @commonHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get commonHigh;

  /// No description provided for @commonInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get commonInfo;

  /// No description provided for @commonCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get commonCritical;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get commonDueDate;

  /// No description provided for @commonAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get commonAccount;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get commonExpense;

  /// No description provided for @commonTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get commonTransfer;

  /// No description provided for @commonRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get commonRefund;

  /// No description provided for @commonAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get commonAdjustment;

  /// No description provided for @commonCreditCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Credit card payment'**
  String get commonCreditCardPayment;

  /// No description provided for @commonChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get commonChecking;

  /// No description provided for @commonSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get commonSavings;

  /// No description provided for @commonCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get commonCard;

  /// No description provided for @commonBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get commonBuiltIn;

  /// No description provided for @commonHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get commonHidden;

  /// No description provided for @commonVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get commonVisible;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @commonCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get commonCategories;

  /// No description provided for @commonRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get commonRules;

  /// No description provided for @commonHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get commonHistory;

  /// No description provided for @commonPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get commonPeople;

  /// No description provided for @commonPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get commonPreferences;

  /// No description provided for @commonPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get commonPerson;

  /// No description provided for @commonPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get commonPlan;

  /// No description provided for @commonRule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get commonRule;

  /// No description provided for @commonMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get commonMemory;

  /// No description provided for @commonConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get commonConversation;

  /// No description provided for @commonUndated.
  ///
  /// In en, this message translates to:
  /// **'Undated'**
  String get commonUndated;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get commonOlder;

  /// No description provided for @commonUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get commonUpcoming;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @commonAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get commonAttachment;

  /// No description provided for @commonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// No description provided for @commonEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get commonEnd;

  /// No description provided for @commonLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get commonLeft;

  /// No description provided for @commonOver.
  ///
  /// In en, this message translates to:
  /// **'Over'**
  String get commonOver;

  /// No description provided for @commonSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get commonSpent;

  /// No description provided for @commonBudgeted.
  ///
  /// In en, this message translates to:
  /// **'Budgeted'**
  String get commonBudgeted;

  /// No description provided for @commonMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get commonMonthly;

  /// No description provided for @commonWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get commonWeekly;

  /// No description provided for @commonOnTrack.
  ///
  /// In en, this message translates to:
  /// **'{onTrack}/{budgeted} on track'**
  String commonOnTrack(int onTrack, int budgeted);

  /// No description provided for @commonTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions'**
  String commonTransactionCount(int count);

  /// No description provided for @commonTransactionCountOne.
  ///
  /// In en, this message translates to:
  /// **'1 transaction'**
  String get commonTransactionCountOne;

  /// No description provided for @commonRecordsApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied to {count, plural, one{1 record} other{{count} records}}.'**
  String commonRecordsApplied(int count);

  /// No description provided for @commonAiCalls.
  ///
  /// In en, this message translates to:
  /// **'{count} AI calls'**
  String commonAiCalls(int count);

  /// No description provided for @commonAiCallsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} AI calls this month'**
  String commonAiCallsThisMonth(int count);

  /// No description provided for @commonMinutesFormat.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String commonMinutesFormat(String minutes);

  /// No description provided for @commonMinutesUnderOne.
  ///
  /// In en, this message translates to:
  /// **'<1 min'**
  String get commonMinutesUnderOne;

  /// No description provided for @commonAddedDate.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String commonAddedDate(String date);

  /// No description provided for @commonUpdatedDate.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String commonUpdatedDate(String date);

  /// No description provided for @commonDueDateValue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String commonDueDateValue(String date);

  /// No description provided for @commonTargetDateValue.
  ///
  /// In en, this message translates to:
  /// **'Target {date}'**
  String commonTargetDateValue(String date);

  /// No description provided for @commonLabeledValue.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String commonLabeledValue(String label, String value);

  /// No description provided for @commonAcrossAccounts.
  ///
  /// In en, this message translates to:
  /// **'Across {accountCount} connected account{accountCountSuffix}'**
  String commonAcrossAccounts(int accountCount, String accountCountSuffix);

  /// No description provided for @commonConnectedAccountCount.
  ///
  /// In en, this message translates to:
  /// **'{count} connected account{countSuffix}'**
  String commonConnectedAccountCount(int count, String countSuffix);

  /// No description provided for @commonCopiedLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} copied.'**
  String commonCopiedLabel(String label);

  /// No description provided for @commonArchivedNamed.
  ///
  /// In en, this message translates to:
  /// **'{label} deleted'**
  String commonArchivedNamed(String label);

  /// No description provided for @commonCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated'**
  String get commonCommaSeparated;

  /// No description provided for @commonAmountHintDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get commonAmountHintDash;

  /// No description provided for @commonMonthYear.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String commonMonthYear(String month, String year);

  /// No description provided for @commonMonthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get commonMonthJanuary;

  /// No description provided for @commonMonthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get commonMonthFebruary;

  /// No description provided for @commonMonthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get commonMonthMarch;

  /// No description provided for @commonMonthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get commonMonthApril;

  /// No description provided for @commonMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get commonMonthMay;

  /// No description provided for @commonMonthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get commonMonthJune;

  /// No description provided for @commonMonthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get commonMonthJuly;

  /// No description provided for @commonMonthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get commonMonthAugust;

  /// No description provided for @commonMonthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get commonMonthSeptember;

  /// No description provided for @commonMonthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get commonMonthOctober;

  /// No description provided for @commonMonthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get commonMonthNovember;

  /// No description provided for @commonMonthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get commonMonthDecember;

  /// No description provided for @commonMonthShortJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get commonMonthShortJan;

  /// No description provided for @commonMonthShortFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get commonMonthShortFeb;

  /// No description provided for @commonMonthShortMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get commonMonthShortMar;

  /// No description provided for @commonMonthShortApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get commonMonthShortApr;

  /// No description provided for @commonMonthShortMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get commonMonthShortMay;

  /// No description provided for @commonMonthShortJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get commonMonthShortJun;

  /// No description provided for @commonMonthShortJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get commonMonthShortJul;

  /// No description provided for @commonMonthShortAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get commonMonthShortAug;

  /// No description provided for @commonMonthShortSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get commonMonthShortSep;

  /// No description provided for @commonMonthShortOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get commonMonthShortOct;

  /// No description provided for @commonMonthShortNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get commonMonthShortNov;

  /// No description provided for @commonMonthShortDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get commonMonthShortDec;

  /// No description provided for @commonMonthShortOld.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get commonMonthShortOld;

  /// No description provided for @bootErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Clarity could not start'**
  String get bootErrorTitle;

  /// No description provided for @bootErrorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get bootErrorTryAgain;

  /// No description provided for @bootErrorFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get bootErrorFallbackMessage;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Clarity'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name your Clarity space. Next, you can connect your bank or use CSV as a manual fallback.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingNameHint.
  ///
  /// In en, this message translates to:
  /// **'Pedro'**
  String get onboardingNameHint;

  /// No description provided for @profileScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileScreenTitle;

  /// No description provided for @profileEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile name'**
  String get profileEditNameTitle;

  /// No description provided for @profileUpdatedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdatedSnackBar;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update profile.'**
  String get profileUpdateFailed;

  /// No description provided for @profileSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get profileSignOutTitle;

  /// No description provided for @profileSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You can sign back in when you are ready.'**
  String get profileSignOutBody;

  /// No description provided for @profileDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'Clarity user'**
  String get profileDefaultUserName;

  /// No description provided for @profileAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountSection;

  /// No description provided for @profileNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileNameTitle;

  /// No description provided for @profileAddYourName.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileAddYourName;

  /// No description provided for @profileMfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-factor authentication'**
  String get profileMfaTitle;

  /// No description provided for @profileMfaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app setup and security options'**
  String get profileMfaSubtitle;

  /// No description provided for @profileRexVoiceSection.
  ///
  /// In en, this message translates to:
  /// **'Rex and voice'**
  String get profileRexVoiceSection;

  /// No description provided for @profileVoiceUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice usage'**
  String get profileVoiceUsageTitle;

  /// No description provided for @profileVoiceUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Minutes today, this week, and this month on web and mobile'**
  String get profileVoiceUsageSubtitle;

  /// No description provided for @profileSessionSection.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get profileSessionSection;

  /// No description provided for @profileSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this device signed out of Clarity'**
  String get profileSignOutSubtitle;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your Clarity account and saved data. Bank connections will be removed. This cannot be undone.'**
  String get profileDeleteAccountBody;

  /// No description provided for @profileDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccountConfirm;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your Clarity account and data'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Try again or contact support.'**
  String get profileDeleteAccountFailed;

  /// No description provided for @profileHeaderLabel.
  ///
  /// In en, this message translates to:
  /// **'Clarity profile'**
  String get profileHeaderLabel;

  /// No description provided for @usageSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice usage'**
  String get usageSummaryTitle;

  /// No description provided for @usageSummaryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading usage'**
  String get usageSummaryLoading;

  /// No description provided for @usageSummaryDailyVoiceMinutes.
  ///
  /// In en, this message translates to:
  /// **'Daily voice minutes'**
  String get usageSummaryDailyVoiceMinutes;

  /// No description provided for @usageSummaryDailyAiCalls.
  ///
  /// In en, this message translates to:
  /// **'Daily AI calls'**
  String get usageSummaryDailyAiCalls;

  /// No description provided for @usageSummaryHeaderLabel.
  ///
  /// In en, this message translates to:
  /// **'Rex voice activity'**
  String get usageSummaryHeaderLabel;

  /// No description provided for @homeShellBankConnectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bank connected successfully: {institutionName}{accountsSyncedSuffix}.'**
  String homeShellBankConnectedSuccess(
    String institutionName,
    String accountsSyncedSuffix,
  );

  /// No description provided for @homeShellBankConnectedYourBank.
  ///
  /// In en, this message translates to:
  /// **'your bank'**
  String get homeShellBankConnectedYourBank;

  /// No description provided for @homeShellBankConnectedAccountsSynced.
  ///
  /// In en, this message translates to:
  /// **' and synced {count, plural, one{1 account} other{{count} accounts}}'**
  String homeShellBankConnectedAccountsSynced(int count);

  /// No description provided for @homeShellBankConnectionStoppedWithCode.
  ///
  /// In en, this message translates to:
  /// **'Bank connection stopped before it finished. You can try again. ({errorCode})'**
  String homeShellBankConnectionStoppedWithCode(String errorCode);

  /// No description provided for @homeShellBankConnectionStoppedWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Bank connection stopped before it finished. Plaid status: {status}.'**
  String homeShellBankConnectionStoppedWithStatus(String status);

  /// No description provided for @homeShellBankConnectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Bank connection cancelled. No account was added.'**
  String get homeShellBankConnectionCancelled;

  /// No description provided for @homeShellBankConnectionOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open bank connection.'**
  String get homeShellBankConnectionOpenFailed;

  /// No description provided for @dashboardOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get dashboardOverviewTitle;

  /// No description provided for @dashboardOverviewImportCsvTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import CSV instead'**
  String get dashboardOverviewImportCsvTooltip;

  /// No description provided for @dashboardOverviewDeleteCsvUploadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete CSV upload'**
  String get dashboardOverviewDeleteCsvUploadTooltip;

  /// No description provided for @dashboardOverviewDeleteAccountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get dashboardOverviewDeleteAccountTooltip;

  /// No description provided for @dashboardOverviewMonthlyCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Monthly cash flow'**
  String get dashboardOverviewMonthlyCashFlow;

  /// No description provided for @dashboardOverviewSpendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get dashboardOverviewSpendingByCategory;

  /// No description provided for @dashboardOverviewIncomeVsSpending.
  ///
  /// In en, this message translates to:
  /// **'Income vs spending'**
  String get dashboardOverviewIncomeVsSpending;

  /// No description provided for @dashboardOverviewSixMonthTrend.
  ///
  /// In en, this message translates to:
  /// **'Six-month spend trend'**
  String get dashboardOverviewSixMonthTrend;

  /// No description provided for @dashboardOverviewSpendingPressure.
  ///
  /// In en, this message translates to:
  /// **'Spending pressure'**
  String get dashboardOverviewSpendingPressure;

  /// No description provided for @dashboardOverviewBudgetPerformance.
  ///
  /// In en, this message translates to:
  /// **'Budget performance'**
  String get dashboardOverviewBudgetPerformance;

  /// No description provided for @dashboardOverviewAccountHealth.
  ///
  /// In en, this message translates to:
  /// **'Account health'**
  String get dashboardOverviewAccountHealth;

  /// No description provided for @dashboardOverviewDataLoadBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Some financial data could not load'**
  String get dashboardOverviewDataLoadBannerTitle;

  /// No description provided for @dashboardOverviewDataLoadBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Clarity is showing the available records, but {sourceLabel} may be incomplete. Rex will treat finance answers as degraded until this refreshes.'**
  String dashboardOverviewDataLoadBannerBody(String sourceLabel);

  /// No description provided for @dashboardOverviewDataLoadBannerFallbackSource.
  ///
  /// In en, this message translates to:
  /// **'financial data'**
  String get dashboardOverviewDataLoadBannerFallbackSource;

  /// No description provided for @dashboardOverviewLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading your financial data...'**
  String get dashboardOverviewLoadingLabel;

  /// No description provided for @dashboardEmptyConnectFirstBankTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your first bank'**
  String get dashboardEmptyConnectFirstBankTitle;

  /// No description provided for @dashboardEmptyConnectFirstBankBody.
  ///
  /// In en, this message translates to:
  /// **'Clarity works best with connected accounts, so balances and transactions stay current automatically.'**
  String get dashboardEmptyConnectFirstBankBody;

  /// No description provided for @dashboardResolvingTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolving imported transactions'**
  String get dashboardResolvingTitle;

  /// No description provided for @dashboardResolvingBody.
  ///
  /// In en, this message translates to:
  /// **'Your statement is connected, but the transaction rows are still loading. Values will appear when the read model is complete.'**
  String get dashboardResolvingBody;

  /// No description provided for @dashboardOverviewTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get dashboardOverviewTotalBalance;

  /// No description provided for @dashboardOverviewAccountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account balance'**
  String get dashboardOverviewAccountBalance;

  /// No description provided for @dashboardOverviewFromConnectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'From your connected accounts'**
  String get dashboardOverviewFromConnectedAccounts;

  /// No description provided for @dashboardOverviewThisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashboardOverviewThisMonthLabel;

  /// No description provided for @dashboardOverviewActivityNotBalanceNote.
  ///
  /// In en, this message translates to:
  /// **'Activity this month — not the same as balance'**
  String get dashboardOverviewActivityNotBalanceNote;

  /// No description provided for @dashboardInsightsStripTitle.
  ///
  /// In en, this message translates to:
  /// **'What to watch'**
  String get dashboardInsightsStripTitle;

  /// No description provided for @dashboardInsightsNetNegative.
  ///
  /// In en, this message translates to:
  /// **'Spending exceeds income by {amount} this month.'**
  String dashboardInsightsNetNegative(String amount);

  /// No description provided for @dashboardInsightsNetPositive.
  ///
  /// In en, this message translates to:
  /// **'Net cash flow is {amount} ahead this month.'**
  String dashboardInsightsNetPositive(String amount);

  /// No description provided for @dashboardInsightsNetBalanced.
  ///
  /// In en, this message translates to:
  /// **'Income and spending are balanced this month.'**
  String get dashboardInsightsNetBalanced;

  /// No description provided for @dashboardInsightsMomLeakUp.
  ///
  /// In en, this message translates to:
  /// **'{category} rose {percent} month-over-month ({amount}).'**
  String dashboardInsightsMomLeakUp(
    String category,
    String percent,
    String amount,
  );

  /// No description provided for @dashboardInsightsMomLeakNew.
  ///
  /// In en, this message translates to:
  /// **'{category} is new spending pressure at {amount} this month.'**
  String dashboardInsightsMomLeakNew(String category, String amount);

  /// No description provided for @dashboardInsightsBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'{category} is over budget by {amount}.'**
  String dashboardInsightsBudgetOver(String category, String amount);

  /// No description provided for @dashboardInsightsSeeChart.
  ///
  /// In en, this message translates to:
  /// **'See chart'**
  String get dashboardInsightsSeeChart;

  /// No description provided for @insightsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get insightsSeeAll;

  /// No description provided for @insightsFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsFeedTitle;

  /// No description provided for @insightsOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsOpenTooltip;

  /// No description provided for @insightsCurrentSection.
  ///
  /// In en, this message translates to:
  /// **'What needs attention'**
  String get insightsCurrentSection;

  /// No description provided for @insightsSavedSection.
  ///
  /// In en, this message translates to:
  /// **'Saved alerts'**
  String get insightsSavedSection;

  /// No description provided for @insightsFeedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No current signals right now. Check back after new spending or budget activity.'**
  String get insightsFeedEmpty;

  /// No description provided for @insightsSavedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved alerts yet. Turn on proactive insights in Profile to keep alerts over time.'**
  String get insightsSavedEmpty;

  /// No description provided for @insightsOptInRequired.
  ///
  /// In en, this message translates to:
  /// **'Optional: turn on proactive insights in Profile to save alerts over time.'**
  String get insightsOptInRequired;

  /// No description provided for @insightsReviewDashboard.
  ///
  /// In en, this message translates to:
  /// **'Review on Dashboard'**
  String get insightsReviewDashboard;

  /// No description provided for @insightsTypeSpendingPressure.
  ///
  /// In en, this message translates to:
  /// **'Spending pressure'**
  String get insightsTypeSpendingPressure;

  /// No description provided for @insightsTypeBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get insightsTypeBudgetOver;

  /// No description provided for @insightsTypeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get insightsTypeCashFlow;

  /// No description provided for @insightsTypeAccountability.
  ///
  /// In en, this message translates to:
  /// **'Goals & habits'**
  String get insightsTypeAccountability;

  /// No description provided for @insightsGuidanceSpendingPressure.
  ///
  /// In en, this message translates to:
  /// **'This category is driving unusual spend. Review recent transactions and decide whether to cut back or set a clearer budget.'**
  String get insightsGuidanceSpendingPressure;

  /// No description provided for @insightsGuidanceBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'This budget is already over. Adjust the limit if the spend is intentional, or pause related purchases until the period resets.'**
  String get insightsGuidanceBudgetOver;

  /// No description provided for @insightsGuidanceCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Net cash flow needs a closer look this month. Compare income and spending before new commitments.'**
  String get insightsGuidanceCashFlow;

  /// No description provided for @insightsGuidanceAccountability.
  ///
  /// In en, this message translates to:
  /// **'A goal or open thread needs a check-in. Open Goals to update progress or adjust the plan.'**
  String get insightsGuidanceAccountability;

  /// No description provided for @insightsSourceDashboard.
  ///
  /// In en, this message translates to:
  /// **'From your dashboard'**
  String get insightsSourceDashboard;

  /// No description provided for @insightsSourceAccountability.
  ///
  /// In en, this message translates to:
  /// **'From goals & accountability'**
  String get insightsSourceAccountability;

  /// No description provided for @insightsStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Saved insights storage is not available yet. Live signals above still work from your dashboard data.'**
  String get insightsStorageUnavailable;

  /// No description provided for @insightsApiUnreadableError.
  ///
  /// In en, this message translates to:
  /// **'Backend returned an unreadable error.'**
  String get insightsApiUnreadableError;

  /// No description provided for @insightsApiGenericError.
  ///
  /// In en, this message translates to:
  /// **'Clarity API returned an error.'**
  String get insightsApiGenericError;

  /// No description provided for @insightsApiInvalidListResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid insights list response.'**
  String get insightsApiInvalidListResponse;

  /// No description provided for @insightsApiInvalidListPayload.
  ///
  /// In en, this message translates to:
  /// **'Invalid insights list payload.'**
  String get insightsApiInvalidListPayload;

  /// No description provided for @insightsApiInvalidSyncResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid insights sync response.'**
  String get insightsApiInvalidSyncResponse;

  /// No description provided for @insightsApiInvalidMarkReadResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid mark-read response.'**
  String get insightsApiInvalidMarkReadResponse;

  /// No description provided for @profileProactiveInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proactive financial insights'**
  String get profileProactiveInsightsTitle;

  /// No description provided for @profileProactiveInsightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save deterministic alerts when your data changes. No background monitoring runs until you turn this on.'**
  String get profileProactiveInsightsSubtitle;

  /// No description provided for @assistantCompanionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Companion saves'**
  String get assistantCompanionSettingsTitle;

  /// No description provided for @assistantCompanionSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how Rex suggests goals, open threads, and memory during chat. Off = chat only. Text = say yes in chat. Card = confirm card.'**
  String get assistantCompanionSettingsSubtitle;

  /// No description provided for @assistantCompanionSettingsGearLabel.
  ///
  /// In en, this message translates to:
  /// **'Companion save settings'**
  String get assistantCompanionSettingsGearLabel;

  /// No description provided for @assistantCompanionSettingsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get assistantCompanionSettingsTabLabel;

  /// No description provided for @assistantAutoProposalsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto suggestions'**
  String get assistantAutoProposalsModeLabel;

  /// No description provided for @assistantAutoProposalsModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get assistantAutoProposalsModeOff;

  /// No description provided for @assistantAutoProposalsModeText.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get assistantAutoProposalsModeText;

  /// No description provided for @assistantAutoProposalsModeCard.
  ///
  /// In en, this message translates to:
  /// **'Confirm card'**
  String get assistantAutoProposalsModeCard;

  /// No description provided for @assistantAutoProposalsModeOffHint.
  ///
  /// In en, this message translates to:
  /// **'Rex never offers saves on its own. It still does what you ask.'**
  String get assistantAutoProposalsModeOffHint;

  /// No description provided for @assistantAutoProposalsModeTextHint.
  ///
  /// In en, this message translates to:
  /// **'Rex asks in chat (say yes to save). No confirm card.'**
  String get assistantAutoProposalsModeTextHint;

  /// No description provided for @assistantAutoProposalsModeCardHint.
  ///
  /// In en, this message translates to:
  /// **'Rex shows an editable confirm card before saving.'**
  String get assistantAutoProposalsModeCardHint;

  /// No description provided for @assistantAutoProposalsTypeThreads.
  ///
  /// In en, this message translates to:
  /// **'Open threads (habits & check-ins)'**
  String get assistantAutoProposalsTypeThreads;

  /// No description provided for @assistantAutoProposalsTypeGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals (things to achieve)'**
  String get assistantAutoProposalsTypeGoals;

  /// No description provided for @assistantAutoProposalsTypeMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory (facts & preferences)'**
  String get assistantAutoProposalsTypeMemory;

  /// No description provided for @assistantFinanceEditsEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow Rex to edit finances'**
  String get assistantFinanceEditsEnabledLabel;

  /// No description provided for @assistantFinanceEditsEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, Rex can advise but won\'t propose transaction or budget changes.'**
  String get assistantFinanceEditsEnabledSubtitle;

  /// No description provided for @chatShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get chatShowMore;

  /// No description provided for @chatShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get chatShowLess;

  /// No description provided for @dashboardChartCategorySpendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This month total'**
  String get dashboardChartCategorySpendSubtitle;

  /// No description provided for @dashboardChartSpendingPressureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Month-over-month pressure'**
  String get dashboardChartSpendingPressureSubtitle;

  /// No description provided for @dashboardSectionCoreCharts.
  ///
  /// In en, this message translates to:
  /// **'Core charts'**
  String get dashboardSectionCoreCharts;

  /// No description provided for @dashboardSectionTrendCharts.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get dashboardSectionTrendCharts;

  /// No description provided for @dashboardSectionTrendChartsHint.
  ///
  /// In en, this message translates to:
  /// **'Income mix and six-month history'**
  String get dashboardSectionTrendChartsHint;

  /// No description provided for @dashboardSectionSpendingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Spending analysis'**
  String get dashboardSectionSpendingAnalysis;

  /// No description provided for @dashboardSectionSpendingAnalysisHint.
  ///
  /// In en, this message translates to:
  /// **'Categories rising vs last month'**
  String get dashboardSectionSpendingAnalysisHint;

  /// No description provided for @dashboardTransactionsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get dashboardTransactionsSectionTitle;

  /// No description provided for @transactionsMiniAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'This month at a glance'**
  String get transactionsMiniAnalyticsTitle;

  /// No description provided for @transactionsMiniAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Same totals as Dashboard for the current month'**
  String get transactionsMiniAnalyticsSubtitle;

  /// No description provided for @transactionsMiniAnalyticsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get transactionsMiniAnalyticsSpent;

  /// No description provided for @transactionsMiniAnalyticsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionsMiniAnalyticsIncome;

  /// No description provided for @transactionsMiniAnalyticsNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get transactionsMiniAnalyticsNet;

  /// No description provided for @transactionsMiniAnalyticsTrend.
  ///
  /// In en, this message translates to:
  /// **'Six-month spend trend'**
  String get transactionsMiniAnalyticsTrend;

  /// No description provided for @transactionsMiniAnalyticsTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get transactionsMiniAnalyticsTopCategories;

  /// No description provided for @dashboardTransactionsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get dashboardTransactionsClearFilters;

  /// No description provided for @dashboardTransactionsLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading transactions'**
  String get dashboardTransactionsLoadingLabel;

  /// No description provided for @dashboardTransactionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions.'**
  String get dashboardTransactionsLoadError;

  /// No description provided for @dashboardTransactionsNoImportedHistory.
  ///
  /// In en, this message translates to:
  /// **'No imported history'**
  String get dashboardTransactionsNoImportedHistory;

  /// No description provided for @dashboardTransactionsModeMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get dashboardTransactionsModeMonths;

  /// No description provided for @dashboardTransactionsModeCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get dashboardTransactionsModeCategories;

  /// No description provided for @dashboardTransactionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search merchant, category, month, or amount'**
  String get dashboardTransactionsSearchHint;

  /// No description provided for @dashboardTransactionsFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get dashboardTransactionsFilterCategory;

  /// No description provided for @dashboardTransactionsFilterAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get dashboardTransactionsFilterAllCategories;

  /// No description provided for @dashboardTransactionsFilterAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get dashboardTransactionsFilterAccount;

  /// No description provided for @dashboardTransactionsFilterAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get dashboardTransactionsFilterAllAccounts;

  /// No description provided for @dashboardTransactionsFilterRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get dashboardTransactionsFilterRole;

  /// No description provided for @dashboardTransactionsFilterAllRoles.
  ///
  /// In en, this message translates to:
  /// **'All roles'**
  String get dashboardTransactionsFilterAllRoles;

  /// No description provided for @dashboardTransactionsTimeFilterAllHistory.
  ///
  /// In en, this message translates to:
  /// **'All history'**
  String get dashboardTransactionsTimeFilterAllHistory;

  /// No description provided for @dashboardTransactionsTimeFilterDashboardMonth.
  ///
  /// In en, this message translates to:
  /// **'Dashboard month'**
  String get dashboardTransactionsTimeFilterDashboardMonth;

  /// No description provided for @dashboardTransactionsTimeFilterLatestTxMonth.
  ///
  /// In en, this message translates to:
  /// **'Latest tx month'**
  String get dashboardTransactionsTimeFilterLatestTxMonth;

  /// No description provided for @dashboardTransactionsTimeFilterLatestTxYear.
  ///
  /// In en, this message translates to:
  /// **'Latest tx year'**
  String get dashboardTransactionsTimeFilterLatestTxYear;

  /// No description provided for @dashboardTransactionsSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get dashboardTransactionsSortNewest;

  /// No description provided for @dashboardTransactionsSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get dashboardTransactionsSortOldest;

  /// No description provided for @dashboardTransactionsSortLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get dashboardTransactionsSortLargest;

  /// No description provided for @dashboardTransactionsSortMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant A-Z'**
  String get dashboardTransactionsSortMerchant;

  /// No description provided for @dashboardTransactionsNoCategoriesMatch.
  ///
  /// In en, this message translates to:
  /// **'No categories match.'**
  String get dashboardTransactionsNoCategoriesMatch;

  /// No description provided for @dashboardTransactionsNoMonthsAfterFilter.
  ///
  /// In en, this message translates to:
  /// **'No months to show after filtering this file.'**
  String get dashboardTransactionsNoMonthsAfterFilter;

  /// No description provided for @dashboardTransactionsNetLabel.
  ///
  /// In en, this message translates to:
  /// **'net'**
  String get dashboardTransactionsNetLabel;

  /// No description provided for @dashboardTransactionsHistoryRange.
  ///
  /// In en, this message translates to:
  /// **'History: {dateRange}'**
  String dashboardTransactionsHistoryRange(String dateRange);

  /// No description provided for @dashboardTransactionsDashboardMonthRange.
  ///
  /// In en, this message translates to:
  /// **'Dashboard month: {dateRange}'**
  String dashboardTransactionsDashboardMonthRange(String dateRange);

  /// No description provided for @dashboardTransactionsLatestTxMonthRange.
  ///
  /// In en, this message translates to:
  /// **'Latest transaction month: {dateRange}'**
  String dashboardTransactionsLatestTxMonthRange(String dateRange);

  /// No description provided for @dashboardTransactionsLatestTxYearRange.
  ///
  /// In en, this message translates to:
  /// **'Latest transaction year: {dateRange}'**
  String dashboardTransactionsLatestTxYearRange(String dateRange);

  /// No description provided for @dashboardTransactionsTapMonthHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a month to inspect transactions | {dateRangeDescription}'**
  String dashboardTransactionsTapMonthHint(String dateRangeDescription);

  /// No description provided for @dashboardTransactionsFilteredCount.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total} transactions | {dateRangeDescription}'**
  String dashboardTransactionsFilteredCount(
    int filtered,
    int total,
    String dateRangeDescription,
  );

  /// No description provided for @accountsScreenRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh accounts'**
  String get accountsScreenRefreshTooltip;

  /// No description provided for @accountsScreenAddAccountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsScreenAddAccountTooltip;

  /// No description provided for @accountsScreenLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts.'**
  String get accountsScreenLoadError;

  /// No description provided for @accountsScreenLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading accounts'**
  String get accountsScreenLoadingLabel;

  /// No description provided for @accountsSummaryTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get accountsSummaryTotalBalance;

  /// No description provided for @accountsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your accounts'**
  String get accountsEmptyTitle;

  /// No description provided for @accountsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start with connected bank accounts so Clarity can keep balances and transactions current.'**
  String get accountsEmptyBody;

  /// No description provided for @connectBankCardConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect Bank'**
  String get connectBankCardConnectButton;

  /// No description provided for @connectBankCardImportCsvButton.
  ///
  /// In en, this message translates to:
  /// **'Import CSV instead'**
  String get connectBankCardImportCsvButton;

  /// No description provided for @connectBankCardAddManualButton.
  ///
  /// In en, this message translates to:
  /// **'Add manual account'**
  String get connectBankCardAddManualButton;

  /// No description provided for @csvImportMobileOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'Import CSV is available in the mobile app for now.'**
  String get csvImportMobileOnlyMessage;

  /// No description provided for @plaidConnectWebUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Bank connect isn\'t available on this device. Use the iOS or Android app to link accounts.'**
  String get plaidConnectWebUnavailableMessage;

  /// No description provided for @accountsNoticeDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get accountsNoticeDismissTooltip;

  /// No description provided for @accountTileThisMonthNet.
  ///
  /// In en, this message translates to:
  /// **'This month {amount} net'**
  String accountTileThisMonthNet(String amount);

  /// No description provided for @accountTileViewAccount.
  ///
  /// In en, this message translates to:
  /// **'View account'**
  String get accountTileViewAccount;

  /// No description provided for @plaidAccountAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get plaidAccountAvailableLabel;

  /// No description provided for @plaidAccountThisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get plaidAccountThisMonthLabel;

  /// No description provided for @plaidAccountInOutSummary.
  ///
  /// In en, this message translates to:
  /// **'{income} in / {spending} out'**
  String plaidAccountInOutSummary(String income, String spending);

  /// No description provided for @plaidAccountLastSyncedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Last synced unavailable'**
  String get plaidAccountLastSyncedUnavailable;

  /// No description provided for @plaidAccountLastSyncedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Last synced just now'**
  String get plaidAccountLastSyncedJustNow;

  /// No description provided for @plaidAccountLastSyncedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Last synced {minutes}m ago'**
  String plaidAccountLastSyncedMinutesAgo(int minutes);

  /// No description provided for @plaidAccountLastSyncedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Last synced {hours}h ago'**
  String plaidAccountLastSyncedHoursAgo(int hours);

  /// No description provided for @plaidAccountLastSyncedDate.
  ///
  /// In en, this message translates to:
  /// **'Last synced {date}'**
  String plaidAccountLastSyncedDate(String date);

  /// No description provided for @plaidAccountResyncTooltipSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get plaidAccountResyncTooltipSyncing;

  /// No description provided for @plaidAccountResyncTooltipLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get plaidAccountResyncTooltipLoginRequired;

  /// No description provided for @plaidAccountResyncTooltipExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get plaidAccountResyncTooltipExpiringSoon;

  /// No description provided for @plaidAccountResyncTooltipDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get plaidAccountResyncTooltipDisconnected;

  /// No description provided for @plaidAccountResyncTooltipDefault.
  ///
  /// In en, this message translates to:
  /// **'Resync'**
  String get plaidAccountResyncTooltipDefault;

  /// No description provided for @plaidAccountDisconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect bank'**
  String get plaidAccountDisconnectTooltip;

  /// No description provided for @addAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get addAccountDialogTitle;

  /// No description provided for @addAccountDialogInstitutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Institution (optional)'**
  String get addAccountDialogInstitutionLabel;

  /// No description provided for @addAccountDialogTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get addAccountDialogTypeLabel;

  /// No description provided for @addAccountDialogBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Current balance (optional)'**
  String get addAccountDialogBalanceLabel;

  /// No description provided for @addAccountDialogInvalidBalance.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid balance or leave it blank.'**
  String get addAccountDialogInvalidBalance;

  /// No description provided for @accountsSheetAddAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsSheetAddAccountTitle;

  /// No description provided for @accountsSheetAddAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect another bank with Plaid, or use manual tools when you need a fallback.'**
  String get accountsSheetAddAccountSubtitle;

  /// No description provided for @accountsSheetConnectBankTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect bank'**
  String get accountsSheetConnectBankTitle;

  /// No description provided for @accountsSheetConnectBankSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use Plaid to add another bank.'**
  String get accountsSheetConnectBankSubtitle;

  /// No description provided for @accountsSheetImportCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Import CSV instead'**
  String get accountsSheetImportCsvTitle;

  /// No description provided for @accountsSheetImportCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a manual account for bank files.'**
  String get accountsSheetImportCsvSubtitle;

  /// No description provided for @accountsSheetAddManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Add manual account'**
  String get accountsSheetAddManualTitle;

  /// No description provided for @accountsSheetAddManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track an account without Plaid.'**
  String get accountsSheetAddManualSubtitle;

  /// No description provided for @accountsScreenDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect bank?'**
  String get accountsScreenDisconnectTitle;

  /// No description provided for @accountsScreenDisconnectContent.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {accountName}? This stops future Plaid sync for this bank. Existing history stays in Clarity.'**
  String accountsScreenDisconnectContent(String accountName);

  /// No description provided for @accountsScreenDisconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect bank'**
  String get accountsScreenDisconnectButton;

  /// No description provided for @accountsScreenBankDisconnectedSnack.
  ///
  /// In en, this message translates to:
  /// **'Bank disconnected.'**
  String get accountsScreenBankDisconnectedSnack;

  /// No description provided for @accountsNavigationCouldNotSaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not save account.'**
  String get accountsNavigationCouldNotSaveAccount;

  /// No description provided for @csvPlaidWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Import CSV into connected account?'**
  String get csvPlaidWarningTitle;

  /// No description provided for @csvPlaidWarningContent.
  ///
  /// In en, this message translates to:
  /// **'{accountName} already syncs through Plaid. Importing a CSV here can add duplicate rows if the file overlaps with synced transactions.'**
  String csvPlaidWarningContent(String accountName);

  /// No description provided for @csvPlaidWarningContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue import'**
  String get csvPlaidWarningContinue;

  /// No description provided for @accountSelectionAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Import CSV instead'**
  String get accountSelectionAppBarTitle;

  /// No description provided for @accountSelectionPreviewingCsv.
  ///
  /// In en, this message translates to:
  /// **'Previewing CSV...'**
  String get accountSelectionPreviewingCsv;

  /// No description provided for @accountSelectionCouldNotImport.
  ///
  /// In en, this message translates to:
  /// **'Could not import this file.'**
  String get accountSelectionCouldNotImport;

  /// No description provided for @accountSelectionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a manual account for this CSV'**
  String get accountSelectionEmptyTitle;

  /// No description provided for @accountSelectionAddManualButton.
  ///
  /// In en, this message translates to:
  /// **'Add manual account'**
  String get accountSelectionAddManualButton;

  /// No description provided for @accountSelectionInstructions.
  ///
  /// In en, this message translates to:
  /// **'CSV import is manual. Choose the account this file belongs to; connected bank accounts update automatically.'**
  String get accountSelectionInstructions;

  /// No description provided for @accountSelectionCsvMayDuplicate.
  ///
  /// In en, this message translates to:
  /// **'CSV may duplicate synced rows'**
  String get accountSelectionCsvMayDuplicate;

  /// No description provided for @csvPreviewDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'CSV import preview'**
  String get csvPreviewDialogTitle;

  /// No description provided for @csvPreviewDialogDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get csvPreviewDialogDateRange;

  /// No description provided for @csvPreviewDialogRowsFound.
  ///
  /// In en, this message translates to:
  /// **'Rows found'**
  String get csvPreviewDialogRowsFound;

  /// No description provided for @csvPreviewDialogNewRows.
  ///
  /// In en, this message translates to:
  /// **'New rows'**
  String get csvPreviewDialogNewRows;

  /// No description provided for @csvPreviewDialogDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get csvPreviewDialogDuplicates;

  /// No description provided for @csvPreviewDialogSpendingRows.
  ///
  /// In en, this message translates to:
  /// **'Spending rows'**
  String get csvPreviewDialogSpendingRows;

  /// No description provided for @csvPreviewDialogIncomeRows.
  ///
  /// In en, this message translates to:
  /// **'Income rows'**
  String get csvPreviewDialogIncomeRows;

  /// No description provided for @csvPreviewDialogEndingBalance.
  ///
  /// In en, this message translates to:
  /// **'Ending balance'**
  String get csvPreviewDialogEndingBalance;

  /// No description provided for @csvPreviewDialogNoNewRows.
  ///
  /// In en, this message translates to:
  /// **'No new rows'**
  String get csvPreviewDialogNoNewRows;

  /// No description provided for @accountDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountDetailFallbackTitle;

  /// No description provided for @accountDetailLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading account'**
  String get accountDetailLoadingLabel;

  /// No description provided for @accountDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load account.'**
  String get accountDetailLoadError;

  /// No description provided for @accountDetailDeletingCsvProgress.
  ///
  /// In en, this message translates to:
  /// **'Deleting CSV upload...'**
  String get accountDetailDeletingCsvProgress;

  /// No description provided for @accountDetailDeleteCsvUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete CSV upload'**
  String get accountDetailDeleteCsvUploadTitle;

  /// No description provided for @accountDetailConfirmDeleteCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this CSV upload?'**
  String get accountDetailConfirmDeleteCsvTitle;

  /// No description provided for @accountDetailDeleteUploadButton.
  ///
  /// In en, this message translates to:
  /// **'Delete upload'**
  String get accountDetailDeleteUploadButton;

  /// No description provided for @accountDetailDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get accountDetailDeleteAccountTitle;

  /// No description provided for @accountDetailDeleteAccountContent.
  ///
  /// In en, this message translates to:
  /// **'Delete this account and all its transactions? This cannot be undone.'**
  String get accountDetailDeleteAccountContent;

  /// No description provided for @accountDetailDeleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDetailDeleteAccountButton;

  /// No description provided for @accountDetailKeepCategories.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get accountDetailKeepCategories;

  /// No description provided for @accountDetailDeleteCategories.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountDetailDeleteCategories;

  /// No description provided for @chatPageDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Rex'**
  String get chatPageDefaultTitle;

  /// No description provided for @chatPageSendingImage.
  ///
  /// In en, this message translates to:
  /// **'Sending image…'**
  String get chatPageSendingImage;

  /// No description provided for @chatPageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send message.'**
  String get chatPageSendFailed;

  /// No description provided for @chatPageReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected file.'**
  String get chatPageReadFileFailed;

  /// No description provided for @chatPageStartVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start Rex.'**
  String get chatPageStartVoiceFailed;

  /// No description provided for @chatPageShowVoiceCallTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show voice call'**
  String get chatPageShowVoiceCallTooltip;

  /// No description provided for @chatPageCallRexTooltip.
  ///
  /// In en, this message translates to:
  /// **'Call Rex'**
  String get chatPageCallRexTooltip;

  /// No description provided for @chatInputAttachTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach file or image'**
  String get chatInputAttachTooltip;

  /// No description provided for @chatInputAttachWebTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get chatInputAttachWebTooltip;

  /// No description provided for @chatInputStartVoiceModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start voice mode'**
  String get chatInputStartVoiceModeTooltip;

  /// No description provided for @chatInputVoiceWebTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start browser voice (keep this tab open)'**
  String get chatInputVoiceWebTooltip;

  /// No description provided for @voiceWebUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice isn\'t available here. Use chat, or open Clarity on iOS or Android.'**
  String get voiceWebUnavailableMessage;

  /// No description provided for @voiceWebForegroundOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Browser voice — keep this tab open'**
  String get voiceWebForegroundOnlyHint;

  /// No description provided for @chatInputMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message Assistant…'**
  String get chatInputMessageHint;

  /// No description provided for @chatInputSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatInputSendTooltip;

  /// No description provided for @chatInputRemoveAttachmentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatInputRemoveAttachmentTooltip;

  /// No description provided for @attachmentSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachmentSheetTitle;

  /// No description provided for @attachmentSheetGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get attachmentSheetGalleryTitle;

  /// No description provided for @attachmentSheetGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an image from photos.'**
  String get attachmentSheetGallerySubtitle;

  /// No description provided for @attachmentSheetCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachmentSheetCameraTitle;

  /// No description provided for @attachmentSheetCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a new photo.'**
  String get attachmentSheetCameraSubtitle;

  /// No description provided for @attachmentSheetFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachmentSheetFilesTitle;

  /// No description provided for @attachmentSheetFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF, text, CSV, markdown, or image files.'**
  String get attachmentSheetFilesSubtitle;

  /// No description provided for @chatTranscriptWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'I\'m Rex. Tell me what\'s happening, what changed, or what you want me to remember.'**
  String get chatTranscriptWelcomeMessage;

  /// No description provided for @rexViewOnDashboard.
  ///
  /// In en, this message translates to:
  /// **'View on Dashboard'**
  String get rexViewOnDashboard;

  /// No description provided for @rexRefreshAccounts.
  ///
  /// In en, this message translates to:
  /// **'Refresh accounts'**
  String get rexRefreshAccounts;

  /// No description provided for @chatTranscriptReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rex is ready'**
  String get chatTranscriptReadyTitle;

  /// No description provided for @chatTranscriptPromptRemember.
  ///
  /// In en, this message translates to:
  /// **'What should I remember?'**
  String get chatTranscriptPromptRemember;

  /// No description provided for @chatTranscriptPromptThinkTonight.
  ///
  /// In en, this message translates to:
  /// **'Help me think through tonight.'**
  String get chatTranscriptPromptThinkTonight;

  /// No description provided for @chatTranscriptPromptCheckKnows.
  ///
  /// In en, this message translates to:
  /// **'Check what Clarity knows.'**
  String get chatTranscriptPromptCheckKnows;

  /// No description provided for @chatBubbleClarityAction.
  ///
  /// In en, this message translates to:
  /// **'Clarity action'**
  String get chatBubbleClarityAction;

  /// No description provided for @voicePanelStartTalking.
  ///
  /// In en, this message translates to:
  /// **'Start talking'**
  String get voicePanelStartTalking;

  /// No description provided for @voicePanelProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get voicePanelProcessing;

  /// No description provided for @voicePanelThinkingElapsed.
  ///
  /// In en, this message translates to:
  /// **'Thinking · {elapsed}'**
  String voicePanelThinkingElapsed(String elapsed);

  /// No description provided for @voicePanelThoughtFor.
  ///
  /// In en, this message translates to:
  /// **'Thought for {elapsed}'**
  String voicePanelThoughtFor(String elapsed);

  /// No description provided for @voicePanelMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get voicePanelMuted;

  /// No description provided for @voicePanelSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get voicePanelSettingsTooltip;

  /// No description provided for @voicePanelTryAgainTooltip.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get voicePanelTryAgainTooltip;

  /// No description provided for @voicePanelUnmuteMicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute mic'**
  String get voicePanelUnmuteMicTooltip;

  /// No description provided for @voicePanelMuteMicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute mic'**
  String get voicePanelMuteMicTooltip;

  /// No description provided for @voicePanelEndVoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'End voice'**
  String get voicePanelEndVoiceTooltip;

  /// No description provided for @conversationListTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get conversationListTitle;

  /// No description provided for @conversationListDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation?'**
  String get conversationListDeleteTitle;

  /// No description provided for @conversationListDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the conversation and its messages.'**
  String get conversationListDeleteBody;

  /// No description provided for @conversationListDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete conversation.'**
  String get conversationListDeleteFailed;

  /// No description provided for @conversationListDeletedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted'**
  String get conversationListDeletedSnackBar;

  /// No description provided for @conversationListRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename chat'**
  String get conversationListRenameTitle;

  /// No description provided for @conversationListRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Chat name'**
  String get conversationListRenameHint;

  /// No description provided for @conversationListRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename chat.'**
  String get conversationListRenameFailed;

  /// No description provided for @conversationListRenamedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Chat renamed'**
  String get conversationListRenamedSnackBar;

  /// No description provided for @conversationListNewConversationTooltip.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get conversationListNewConversationTooltip;

  /// No description provided for @conversationListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading chats'**
  String get conversationListLoading;

  /// No description provided for @conversationListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get conversationListEmptyTitle;

  /// No description provided for @conversationListEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Start a fresh conversation when you are ready.'**
  String get conversationListEmptyMessage;

  /// No description provided for @conversationListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get conversationListSearchHint;

  /// No description provided for @conversationListClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get conversationListClearSearchTooltip;

  /// No description provided for @conversationListSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching chats'**
  String get conversationListSearching;

  /// No description provided for @conversationListNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching chats'**
  String get conversationListNoMatchesTitle;

  /// No description provided for @conversationListNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get conversationListNewChat;

  /// No description provided for @conversationHistoryNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get conversationHistoryNewConversation;

  /// No description provided for @conversationHistoryMatchedConversation.
  ///
  /// In en, this message translates to:
  /// **'Matched conversation'**
  String get conversationHistoryMatchedConversation;

  /// No description provided for @conversationHistoryNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get conversationHistoryNoMessagesYet;

  /// No description provided for @conversationHistoryActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get conversationHistoryActionsTooltip;

  /// No description provided for @memoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'What Clarity Knows'**
  String get memoryPageTitle;

  /// No description provided for @memoryPageRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh information'**
  String get memoryPageRefreshTooltip;

  /// No description provided for @memoryPageMemoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Memory updated'**
  String get memoryPageMemoryUpdated;

  /// No description provided for @memoryPageMemoryArchived.
  ///
  /// In en, this message translates to:
  /// **'Memory deleted'**
  String get memoryPageMemoryArchived;

  /// No description provided for @memoryPageActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Memory action failed.'**
  String get memoryPageActionFailed;

  /// No description provided for @memoryHeaderSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search what Clarity knows'**
  String get memoryHeaderSearchHint;

  /// No description provided for @memoryHeaderClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get memoryHeaderClearSearchTooltip;

  /// No description provided for @memoryHeaderSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'What Clarity knows'**
  String get memoryHeaderSectionTitle;

  /// No description provided for @memoryHeaderActiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Active information only'**
  String get memoryHeaderActiveOnly;

  /// No description provided for @memoryOverviewTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 50 saved items in each category. Pull to refresh for the latest information.'**
  String get memoryOverviewTruncated;

  /// No description provided for @memoryGroupFacts.
  ///
  /// In en, this message translates to:
  /// **'Facts'**
  String get memoryGroupFacts;

  /// No description provided for @memoryGroupPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get memoryGroupPreferences;

  /// No description provided for @memoryGroupPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get memoryGroupPeople;

  /// No description provided for @memoryGroupPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get memoryGroupPlaces;

  /// No description provided for @memoryGroupGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get memoryGroupGoals;

  /// No description provided for @memoryGroupRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get memoryGroupRules;

  /// No description provided for @memoryGroupEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get memoryGroupEvents;

  /// No description provided for @memoryGroupOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get memoryGroupOther;

  /// No description provided for @memoryTypeFact.
  ///
  /// In en, this message translates to:
  /// **'Fact'**
  String get memoryTypeFact;

  /// No description provided for @memoryTypePreference.
  ///
  /// In en, this message translates to:
  /// **'Preference'**
  String get memoryTypePreference;

  /// No description provided for @memoryTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get memoryTypeEvent;

  /// No description provided for @memoryTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other memory'**
  String get memoryTypeOther;

  /// No description provided for @memoryEntityTypePlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get memoryEntityTypePlace;

  /// No description provided for @memoryEntityTypeOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get memoryEntityTypeOrganization;

  /// No description provided for @memoryEditEditEntityTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit saved item'**
  String get memoryEditEditEntityTitle;

  /// No description provided for @memoryPageEntityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Saved item updated'**
  String get memoryPageEntityUpdated;

  /// No description provided for @memoryOverviewLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get memoryOverviewLoadMore;

  /// No description provided for @memoryOverviewTruncatedMax.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 100 saved items in each category.'**
  String get memoryOverviewTruncatedMax;

  /// No description provided for @memoryRecordLongTermMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory note'**
  String get memoryRecordLongTermMemory;

  /// No description provided for @memoryRecordMemoryUpdate.
  ///
  /// In en, this message translates to:
  /// **'Memory update'**
  String get memoryRecordMemoryUpdate;

  /// No description provided for @memoryRecordEntity.
  ///
  /// In en, this message translates to:
  /// **'Person / place'**
  String get memoryRecordEntity;

  /// No description provided for @memoryRecordEntityEvent.
  ///
  /// In en, this message translates to:
  /// **'Related event'**
  String get memoryRecordEntityEvent;

  /// No description provided for @memoryRecordPersonalRule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get memoryRecordPersonalRule;

  /// No description provided for @memoryRecordPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get memoryRecordPlan;

  /// No description provided for @memoryRecordPlanMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get memoryRecordPlanMilestone;

  /// No description provided for @memoryRecordCorrection.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get memoryRecordCorrection;

  /// No description provided for @memoryRecordArchive.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memoryRecordArchive;

  /// No description provided for @memoryRecordMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get memoryRecordMerge;

  /// No description provided for @memoryRecordGentleDirect.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminder'**
  String get memoryRecordGentleDirect;

  /// No description provided for @memoryRecordCheckpoint.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint'**
  String get memoryRecordCheckpoint;

  /// No description provided for @memoryRecordApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get memoryRecordApproved;

  /// No description provided for @memoryRecordApplied.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get memoryRecordApplied;

  /// No description provided for @memoryRecordRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get memoryRecordRejected;

  /// No description provided for @memoryRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get memoryRecordFailed;

  /// No description provided for @memoryRecordSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get memoryRecordSkipped;

  /// No description provided for @memoryRecordActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get memoryRecordActive;

  /// No description provided for @memoryRecordInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get memoryRecordInactive;

  /// No description provided for @memoryRecordOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get memoryRecordOpen;

  /// No description provided for @memoryRecordCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get memoryRecordCompleted;

  /// No description provided for @memoryRecordResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get memoryRecordResolved;

  /// No description provided for @memoryRecordDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get memoryRecordDismissed;

  /// No description provided for @memoryRecordArchived.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get memoryRecordArchived;

  /// No description provided for @memoryRecordLowRisk.
  ///
  /// In en, this message translates to:
  /// **'Low risk'**
  String get memoryRecordLowRisk;

  /// No description provided for @memoryRecordMediumRisk.
  ///
  /// In en, this message translates to:
  /// **'Medium risk'**
  String get memoryRecordMediumRisk;

  /// No description provided for @memoryRecordHighRisk.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get memoryRecordHighRisk;

  /// No description provided for @memoryRecordCriticalRisk.
  ///
  /// In en, this message translates to:
  /// **'Critical risk'**
  String get memoryRecordCriticalRisk;

  /// No description provided for @memoryRecordInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get memoryRecordInfo;

  /// No description provided for @memoryRecordEventNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get memoryRecordEventNote;

  /// No description provided for @memoryRecordEventInteraction.
  ///
  /// In en, this message translates to:
  /// **'Interaction'**
  String get memoryRecordEventInteraction;

  /// No description provided for @memoryRecordEventRelationshipUpdate.
  ///
  /// In en, this message translates to:
  /// **'Relationship update'**
  String get memoryRecordEventRelationshipUpdate;

  /// No description provided for @memoryRecordEventConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get memoryRecordEventConflict;

  /// No description provided for @memoryRecordEventMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get memoryRecordEventMilestone;

  /// No description provided for @memoryRecordProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get memoryRecordProject;

  /// No description provided for @memoryRecordTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get memoryRecordTask;

  /// No description provided for @memoryHeaderLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading memory'**
  String get memoryHeaderLoading;

  /// No description provided for @memoryHeaderEmptyActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Clarity is still learning'**
  String get memoryHeaderEmptyActiveTitle;

  /// No description provided for @memoryHeaderEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved information yet'**
  String get memoryHeaderEmptyTitle;

  /// No description provided for @memoryArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete saved information?'**
  String get memoryArchiveTitle;

  /// No description provided for @memoryArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this from Knows? Rex will stop using it in future conversations.'**
  String get memoryArchiveBody;

  /// No description provided for @memoryTileActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Memory actions'**
  String get memoryTileActionsTooltip;

  /// No description provided for @memoryTileQuickEdit.
  ///
  /// In en, this message translates to:
  /// **'Quick edit'**
  String get memoryTileQuickEdit;

  /// No description provided for @memoryTileAddMilestone.
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get memoryTileAddMilestone;

  /// No description provided for @memoryEditEditMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get memoryEditEditMemoryTitle;

  /// No description provided for @memoryEditSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'What Clarity should remember'**
  String get memoryEditSummaryHint;

  /// No description provided for @accountabilityPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get accountabilityPageTitle;

  /// No description provided for @accountabilityPageRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh goals'**
  String get accountabilityPageRefreshTooltip;

  /// No description provided for @accountabilitySharedAddGoal.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get accountabilitySharedAddGoal;

  /// No description provided for @accountabilitySharedAddOpenThread.
  ///
  /// In en, this message translates to:
  /// **'Add open thread'**
  String get accountabilitySharedAddOpenThread;

  /// No description provided for @accountabilitySharedLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading goals'**
  String get accountabilitySharedLoading;

  /// No description provided for @accountabilitySharedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get accountabilitySharedEmptyTitle;

  /// No description provided for @accountabilitySharedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start with one simple goal or tell Rex in chat.'**
  String get accountabilitySharedEmptyBody;

  /// No description provided for @accountabilitySharedAddFirstGoal.
  ///
  /// In en, this message translates to:
  /// **'Add your first goal'**
  String get accountabilitySharedAddFirstGoal;

  /// No description provided for @accountabilitySectionsActiveGoals.
  ///
  /// In en, this message translates to:
  /// **'Active Goals'**
  String get accountabilitySectionsActiveGoals;

  /// No description provided for @accountabilitySectionsNoActiveGoals.
  ///
  /// In en, this message translates to:
  /// **'No active goals yet.'**
  String get accountabilitySectionsNoActiveGoals;

  /// No description provided for @accountabilitySectionsOpenThreads.
  ///
  /// In en, this message translates to:
  /// **'Open Threads'**
  String get accountabilitySectionsOpenThreads;

  /// No description provided for @accountabilitySectionsNoOpenThreads.
  ///
  /// In en, this message translates to:
  /// **'No open threads yet.'**
  String get accountabilitySectionsNoOpenThreads;

  /// No description provided for @accountabilitySectionsNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get accountabilitySectionsNeedsAttention;

  /// No description provided for @accountabilitySectionsNoSignals.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs attention right now.'**
  String get accountabilitySectionsNoSignals;

  /// No description provided for @accountabilitySectionsRuleRisks.
  ///
  /// In en, this message translates to:
  /// **'Rule risks'**
  String get accountabilitySectionsRuleRisks;

  /// No description provided for @accountabilitySectionsNoRuleRisks.
  ///
  /// In en, this message translates to:
  /// **'No rule risks detected.'**
  String get accountabilitySectionsNoRuleRisks;

  /// No description provided for @accountabilitySectionsRecentPatterns.
  ///
  /// In en, this message translates to:
  /// **'Recent patterns'**
  String get accountabilitySectionsRecentPatterns;

  /// No description provided for @accountabilitySectionsNoRecentPatterns.
  ///
  /// In en, this message translates to:
  /// **'No recent patterns to review.'**
  String get accountabilitySectionsNoRecentPatterns;

  /// No description provided for @accountabilityTilesGoalActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Goal actions'**
  String get accountabilityTilesGoalActionsTooltip;

  /// No description provided for @accountabilityTilesOpenThreadActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open thread actions'**
  String get accountabilityTilesOpenThreadActionsTooltip;

  /// No description provided for @accountabilityTilesOpenThreadDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Companion follow-up — not saved memory'**
  String get accountabilityTilesOpenThreadDefaultSubtitle;

  /// No description provided for @accountabilityTilesMarkMissed.
  ///
  /// In en, this message translates to:
  /// **'Mark missed'**
  String get accountabilityTilesMarkMissed;

  /// No description provided for @accountabilityDetailGoalDetails.
  ///
  /// In en, this message translates to:
  /// **'Goal details'**
  String get accountabilityDetailGoalDetails;

  /// No description provided for @accountabilityDetailEditOpenThread.
  ///
  /// In en, this message translates to:
  /// **'Edit open thread'**
  String get accountabilityDetailEditOpenThread;

  /// No description provided for @accountabilityDetailNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Why this matters'**
  String get accountabilityDetailNotesHint;

  /// No description provided for @budgetsScreenManageCategoriesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get budgetsScreenManageCategoriesTooltip;

  /// No description provided for @budgetsScreenSaveChangesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get budgetsScreenSaveChangesTooltip;

  /// No description provided for @budgetsScreenLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load budgets.'**
  String get budgetsScreenLoadError;

  /// No description provided for @budgetsScreenLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading budgets'**
  String get budgetsScreenLoadingLabel;

  /// No description provided for @budgetsScreenBudgetVsSpentTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget vs spent'**
  String get budgetsScreenBudgetVsSpentTitle;

  /// No description provided for @budgetsHeaderSelectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get budgetsHeaderSelectMonth;

  /// No description provided for @budgetsHeaderPickWeekStart.
  ///
  /// In en, this message translates to:
  /// **'Pick week start'**
  String get budgetsHeaderPickWeekStart;

  /// No description provided for @budgetsHeaderNoMonthsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No months available.'**
  String get budgetsHeaderNoMonthsAvailable;

  /// No description provided for @budgetsScreenUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes before switching period?'**
  String get budgetsScreenUnsavedChangesTitle;

  /// No description provided for @budgetsScreenUnsavedChangesContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved budget changes for this period.'**
  String get budgetsScreenUnsavedChangesContent;

  /// No description provided for @budgetsScreenSaveFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not save budgets. Try again.'**
  String get budgetsScreenSaveFailedSnack;

  /// No description provided for @budgetCategoryListTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get budgetCategoryListTitle;

  /// No description provided for @budgetCategoryListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active budget categories yet.'**
  String get budgetCategoryListEmpty;

  /// No description provided for @budgetCategoryRowStatusNoBudget.
  ///
  /// In en, this message translates to:
  /// **'Spent {spent} · No budget'**
  String budgetCategoryRowStatusNoBudget(String spent);

  /// No description provided for @budgetCategoryRowStatusOver.
  ///
  /// In en, this message translates to:
  /// **'Spent {spent} · Over {amount}'**
  String budgetCategoryRowStatusOver(String spent, String amount);

  /// No description provided for @budgetCategoryRowStatusLeft.
  ///
  /// In en, this message translates to:
  /// **'Spent {spent} · Left {amount}'**
  String budgetCategoryRowStatusLeft(String spent, String amount);

  /// No description provided for @categorySheetHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get categorySheetHeaderTitle;

  /// No description provided for @categorySheetAddCustomCategory.
  ///
  /// In en, this message translates to:
  /// **'Add custom category'**
  String get categorySheetAddCustomCategory;

  /// No description provided for @categorySheetSavedCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved categories'**
  String get categorySheetSavedCategoriesLabel;

  /// No description provided for @categorySheetNoSavedCategories.
  ///
  /// In en, this message translates to:
  /// **'No saved categories yet.'**
  String get categorySheetNoSavedCategories;

  /// No description provided for @categorySheetMerchantRulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant rules'**
  String get categorySheetMerchantRulesLabel;

  /// No description provided for @categorySheetNoMerchantRules.
  ///
  /// In en, this message translates to:
  /// **'No learned merchant rules yet.'**
  String get categorySheetNoMerchantRules;

  /// No description provided for @categorySheetRecentChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent changes'**
  String get categorySheetRecentChangesLabel;

  /// No description provided for @categorySheetNoAuditEvents.
  ///
  /// In en, this message translates to:
  /// **'No financial changes recorded yet.'**
  String get categorySheetNoAuditEvents;

  /// No description provided for @categoryDialogNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryDialogNameLabel;

  /// No description provided for @categorySheetAddCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categorySheetAddCategoryTitle;

  /// No description provided for @categorySheetRenameCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get categorySheetRenameCategoryTitle;

  /// No description provided for @categorySheetDeleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get categorySheetDeleteCategoryTitle;

  /// No description provided for @categorySheetMergeCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge category?'**
  String get categorySheetMergeCategoryTitle;

  /// No description provided for @categorySheetMergeButton.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get categorySheetMergeButton;

  /// No description provided for @categorySheetCategoryInUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Category is in use'**
  String get categorySheetCategoryInUseTitle;

  /// No description provided for @categorySheetClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get categorySheetClose;

  /// No description provided for @transactionCategoryAutoRole.
  ///
  /// In en, this message translates to:
  /// **'Auto role'**
  String get transactionCategoryAutoRole;

  /// No description provided for @transactionCategoryFinancialRoleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Financial role'**
  String get transactionCategoryFinancialRoleTooltip;

  /// No description provided for @transactionCategoryNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get transactionCategoryNoCategories;

  /// No description provided for @transactionCategoryNewCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get transactionCategoryNewCategoryHint;

  /// No description provided for @transactionCategoryOnlyThisOne.
  ///
  /// In en, this message translates to:
  /// **'Only this one'**
  String get transactionCategoryOnlyThisOne;

  /// No description provided for @transactionCategoryUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Category updated.'**
  String get transactionCategoryUpdatedSnack;

  /// No description provided for @budgetsScreenSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Budgets saved for {period}'**
  String budgetsScreenSavedSnack(String period);

  /// No description provided for @categorySheetLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading categories'**
  String get categorySheetLoadingLabel;

  /// No description provided for @categorySheetLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories.'**
  String get categorySheetLoadError;

  /// No description provided for @categorySheetCategoryAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Category added.'**
  String get categorySheetCategoryAddedSnack;

  /// No description provided for @categorySheetCategoryRenamedSnack.
  ///
  /// In en, this message translates to:
  /// **'Category renamed.'**
  String get categorySheetCategoryRenamedSnack;

  /// No description provided for @categorySheetDeleteCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is not used by transactions, budgets, or merchant rules. Delete it from saved custom categories?'**
  String categorySheetDeleteCategoryContent(String name);

  /// No description provided for @categorySheetCategoryDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Category deleted.'**
  String get categorySheetCategoryDeletedSnack;

  /// No description provided for @categorySheetCategoryShownSnack.
  ///
  /// In en, this message translates to:
  /// **'Category shown in pickers.'**
  String get categorySheetCategoryShownSnack;

  /// No description provided for @categorySheetCategoryHiddenSnack.
  ///
  /// In en, this message translates to:
  /// **'Category hidden from pickers.'**
  String get categorySheetCategoryHiddenSnack;

  /// No description provided for @categorySheetMergeCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'Merge \"{source}\" into \"{target}\"? This will move {usage} to \"{target}\" and delete \"{source}\".'**
  String categorySheetMergeCategoryContent(
    String source,
    String target,
    String usage,
  );

  /// No description provided for @categorySheetCategoryMergedSnack.
  ///
  /// In en, this message translates to:
  /// **'Category merged.'**
  String get categorySheetCategoryMergedSnack;

  /// No description provided for @categorySheetCategoryInUseContent.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {usage}. Merge it into another category or hide it from pickers instead of deleting it.'**
  String categorySheetCategoryInUseContent(String name, String usage);

  /// No description provided for @categorySheetNoMergeTarget.
  ///
  /// In en, this message translates to:
  /// **'No visible target category to merge into.'**
  String get categorySheetNoMergeTarget;

  /// No description provided for @categorySheetMergeIntoTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge \"{source}\" into'**
  String categorySheetMergeIntoTitle(String source);

  /// No description provided for @categorySheetNoRuleCategory.
  ///
  /// In en, this message translates to:
  /// **'No visible category is available for this rule.'**
  String get categorySheetNoRuleCategory;

  /// No description provided for @categorySheetSetMerchantRuleCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Set merchant rule category'**
  String get categorySheetSetMerchantRuleCategoryTitle;

  /// No description provided for @categorySheetUpdateFutureImportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Update future imports?'**
  String get categorySheetUpdateFutureImportsTitle;

  /// No description provided for @categorySheetUpdateFutureImportsContent.
  ///
  /// In en, this message translates to:
  /// **'Future \"{merchant}\" imports will use \"{category}\". Existing transactions will not be changed.'**
  String categorySheetUpdateFutureImportsContent(
    String merchant,
    String category,
  );

  /// No description provided for @categorySheetUpdateRuleButton.
  ///
  /// In en, this message translates to:
  /// **'Update rule'**
  String get categorySheetUpdateRuleButton;

  /// No description provided for @categorySheetMerchantRuleUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule updated.'**
  String get categorySheetMerchantRuleUpdatedSnack;

  /// No description provided for @categorySheetDisableRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable rule?'**
  String get categorySheetDisableRuleTitle;

  /// No description provided for @categorySheetEnableRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable rule?'**
  String get categorySheetEnableRuleTitle;

  /// No description provided for @categorySheetDisableRuleContent.
  ///
  /// In en, this message translates to:
  /// **'Future \"{merchant}\" imports will stop using this learned category rule.'**
  String categorySheetDisableRuleContent(String merchant);

  /// No description provided for @categorySheetEnableRuleContent.
  ///
  /// In en, this message translates to:
  /// **'Future \"{merchant}\" imports will use this learned category rule again.'**
  String categorySheetEnableRuleContent(String merchant);

  /// No description provided for @categorySheetMerchantRuleDisabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule disabled.'**
  String get categorySheetMerchantRuleDisabledSnack;

  /// No description provided for @categorySheetMerchantRuleEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule enabled.'**
  String get categorySheetMerchantRuleEnabledSnack;

  /// No description provided for @categorySheetDeleteMerchantRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete merchant rule?'**
  String get categorySheetDeleteMerchantRuleTitle;

  /// No description provided for @categorySheetDeleteMerchantRuleContent.
  ///
  /// In en, this message translates to:
  /// **'Future \"{merchant}\" imports will no longer use this learned category rule.'**
  String categorySheetDeleteMerchantRuleContent(String merchant);

  /// No description provided for @categorySheetMerchantRuleDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule deleted.'**
  String get categorySheetMerchantRuleDeletedSnack;

  /// No description provided for @categorySheetSaveFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not save changes: {error}'**
  String categorySheetSaveFailedSnack(String error);

  /// No description provided for @categorySheetBuiltInHint.
  ///
  /// In en, this message translates to:
  /// **'Built-in budget categories are always available: {count}. Used custom categories must be merged or hidden before deletion.'**
  String categorySheetBuiltInHint(int count);

  /// No description provided for @categorySheetMerchantRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Merchant rules affect future CSV imports. Editing a rule does not rewrite existing transactions.'**
  String get categorySheetMerchantRulesHint;

  /// No description provided for @categorySheetCategoryActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Category actions'**
  String get categorySheetCategoryActionsTooltip;

  /// No description provided for @categorySheetShowInPickers.
  ///
  /// In en, this message translates to:
  /// **'Show in pickers'**
  String get categorySheetShowInPickers;

  /// No description provided for @categorySheetHideFromPickers.
  ///
  /// In en, this message translates to:
  /// **'Hide from pickers'**
  String get categorySheetHideFromPickers;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @categorySheetChangeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change category'**
  String get categorySheetChangeCategory;

  /// No description provided for @categorySheetEnableRule.
  ///
  /// In en, this message translates to:
  /// **'Enable rule'**
  String get categorySheetEnableRule;

  /// No description provided for @categorySheetDisableRule.
  ///
  /// In en, this message translates to:
  /// **'Disable rule'**
  String get categorySheetDisableRule;

  /// No description provided for @categorySheetDeleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get categorySheetDeleteRule;

  /// No description provided for @categorySheetMerchantRuleActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule actions'**
  String get categorySheetMerchantRuleActionsTooltip;

  /// No description provided for @categorySheetMissingCategory.
  ///
  /// In en, this message translates to:
  /// **'Missing category'**
  String get categorySheetMissingCategory;

  /// No description provided for @categorySheetAuditTransactionCategoryChanged.
  ///
  /// In en, this message translates to:
  /// **'Transaction category changed'**
  String get categorySheetAuditTransactionCategoryChanged;

  /// No description provided for @categorySheetAuditBulkCategoryChange.
  ///
  /// In en, this message translates to:
  /// **'Bulk category change'**
  String get categorySheetAuditBulkCategoryChange;

  /// No description provided for @categorySheetAuditTransactionRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'Transaction role changed'**
  String get categorySheetAuditTransactionRoleChanged;

  /// No description provided for @categorySheetAuditCategoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categorySheetAuditCategoryDeleted;

  /// No description provided for @categorySheetAuditCategoryMerged.
  ///
  /// In en, this message translates to:
  /// **'Category merged'**
  String get categorySheetAuditCategoryMerged;

  /// No description provided for @categorySheetAuditCategoryVisibilityChanged.
  ///
  /// In en, this message translates to:
  /// **'Category visibility changed'**
  String get categorySheetAuditCategoryVisibilityChanged;

  /// No description provided for @categorySheetAuditMerchantRuleChanged.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule changed'**
  String get categorySheetAuditMerchantRuleChanged;

  /// No description provided for @categorySheetAuditMerchantRuleEnabledDisabled.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule enabled/disabled'**
  String get categorySheetAuditMerchantRuleEnabledDisabled;

  /// No description provided for @categorySheetAuditMerchantRuleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Merchant rule deleted'**
  String get categorySheetAuditMerchantRuleDeleted;

  /// No description provided for @categorySheetAuditCategoryRenamed.
  ///
  /// In en, this message translates to:
  /// **'Category renamed'**
  String get categorySheetAuditCategoryRenamed;

  /// No description provided for @categoryUsageTxCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String categoryUsageTxCount(int count);

  /// No description provided for @categoryUsageBudgetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 budget} other{{count} budgets}}'**
  String categoryUsageBudgetCount(int count);

  /// No description provided for @categoryUsageRuleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 rule} other{{count} rules}}'**
  String categoryUsageRuleCount(int count);

  /// No description provided for @merchantRuleStatsMatchingTx.
  ///
  /// In en, this message translates to:
  /// **'{count} matching tx'**
  String merchantRuleStatsMatchingTx(int count);

  /// No description provided for @merchantRuleStatsMatchingTxLastUsed.
  ///
  /// In en, this message translates to:
  /// **'{count} matching tx · last used {date}'**
  String merchantRuleStatsMatchingTxLastUsed(int count, String date);

  /// No description provided for @transactionCategoryNotFoundSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not find this transaction.'**
  String get transactionCategoryNotFoundSnack;

  /// No description provided for @transactionCategoryUpdateRoleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update role: {error}'**
  String transactionCategoryUpdateRoleFailed(String error);

  /// No description provided for @transactionCategoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String transactionCategoryDeleteTitle(String name);

  /// No description provided for @transactionCategoryDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Remove this category and clear it from assigned transactions?'**
  String get transactionCategoryDeleteContent;

  /// No description provided for @transactionCategoryUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update category: {error}'**
  String transactionCategoryUpdateFailed(String error);

  /// No description provided for @transactionCategoryApplySimilarTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply to similar transactions?'**
  String get transactionCategoryApplySimilarTitle;

  /// No description provided for @transactionCategoryApplySimilarContent.
  ///
  /// In en, this message translates to:
  /// **'Clarity found {count} transactions that look like \"{merchant}\". Apply this category to all of them and remember it for future CSV imports?'**
  String transactionCategoryApplySimilarContent(int count, String merchant);

  /// No description provided for @transactionCategoryUpdateCount.
  ///
  /// In en, this message translates to:
  /// **'Update {count}'**
  String transactionCategoryUpdateCount(int count);

  /// No description provided for @transactionCategoryUpdatedSimilarSnack.
  ///
  /// In en, this message translates to:
  /// **'Updated {count} similar transactions. Choose another category to correct them.'**
  String transactionCategoryUpdatedSimilarSnack(int count);

  /// No description provided for @transactionCategoryUpdatedFutureImportsSnack.
  ///
  /// In en, this message translates to:
  /// **'Category updated. Future matching imports will use it.'**
  String get transactionCategoryUpdatedFutureImportsSnack;

  /// No description provided for @importJobCompleteSnack.
  ///
  /// In en, this message translates to:
  /// **'Import complete.'**
  String get importJobCompleteSnack;

  /// No description provided for @importJobCategoryAssignmentFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Imported {inserted} transactions, but category assignment failed.'**
  String importJobCategoryAssignmentFailedSnack(int inserted);

  /// No description provided for @importJobCategoryRetryNeededPersistent.
  ///
  /// In en, this message translates to:
  /// **'Imported {inserted} transactions, but {failures} need category assignment retry.'**
  String importJobCategoryRetryNeededPersistent(int inserted, int failures);

  /// No description provided for @importJobNeedsCategoryRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Import needs category retry'**
  String get importJobNeedsCategoryRetryTitle;

  /// No description provided for @importJobNoNewTransactionsDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No new transactions imported. {skipped} duplicates skipped.'**
  String importJobNoNewTransactionsDuplicates(int skipped);

  /// No description provided for @importJobNoNewTransactions.
  ///
  /// In en, this message translates to:
  /// **'No new transactions imported.'**
  String get importJobNoNewTransactions;

  /// No description provided for @importJobSuccessWithLocalAndMisc.
  ///
  /// In en, this message translates to:
  /// **'Imported {inserted} transactions. Categorized all; {local} used local rules; {misc} used a best-guess category.'**
  String importJobSuccessWithLocalAndMisc(int inserted, int local, int misc);

  /// No description provided for @importJobSuccessWithLocal.
  ///
  /// In en, this message translates to:
  /// **'Imported {inserted} transactions. Categorized all; {local} used local rules.'**
  String importJobSuccessWithLocal(int inserted, int local);

  /// No description provided for @importJobSuccessWithMisc.
  ///
  /// In en, this message translates to:
  /// **'Imported {inserted} transactions. Categorized all; {misc} used a best-guess category.'**
  String importJobSuccessWithMisc(int inserted, int misc);

  /// No description provided for @importJobSuccessCategorizedAll.
  ///
  /// In en, this message translates to:
  /// **'Imported {inserted} transactions. Categorized all transactions.'**
  String importJobSuccessCategorizedAll(int inserted);

  /// No description provided for @importJobFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importJobFailedTitle;

  /// No description provided for @importJobRetryingCategoryAssignment.
  ///
  /// In en, this message translates to:
  /// **'Retrying category assignment...'**
  String get importJobRetryingCategoryAssignment;

  /// No description provided for @importJobCategoryRetryCompleteProgress.
  ///
  /// In en, this message translates to:
  /// **'Category retry complete.'**
  String get importJobCategoryRetryCompleteProgress;

  /// No description provided for @importJobNoRetryableRowsSnack.
  ///
  /// In en, this message translates to:
  /// **'No retryable category rows found.'**
  String get importJobNoRetryableRowsSnack;

  /// No description provided for @importJobNoRetryableRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'No retryable rows'**
  String get importJobNoRetryableRowsTitle;

  /// No description provided for @importJobRetriedCategoriesSnack.
  ///
  /// In en, this message translates to:
  /// **'Retried categories. Updated {count} transactions.'**
  String importJobRetriedCategoriesSnack(int count);

  /// No description provided for @importJobCategoryRetryCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Category retry complete'**
  String get importJobCategoryRetryCompleteTitle;

  /// No description provided for @importJobCategoryRetryFailedProgress.
  ///
  /// In en, this message translates to:
  /// **'Category retry failed.'**
  String get importJobCategoryRetryFailedProgress;

  /// No description provided for @importJobCategoryRetryFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not retry category assignment: {error}'**
  String importJobCategoryRetryFailedSnack(String error);

  /// No description provided for @importJobCategoryRetryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Category retry failed'**
  String get importJobCategoryRetryFailedTitle;

  /// No description provided for @importJobRetryFailedLine.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {error}'**
  String importJobRetryFailedLine(String error);

  /// No description provided for @importJobSummaryParsedLine.
  ///
  /// In en, this message translates to:
  /// **'Parsed {parsed}; imported {inserted}; skipped {skipped} duplicates.'**
  String importJobSummaryParsedLine(int parsed, int inserted, int skipped);

  /// No description provided for @importJobSummaryAiLine.
  ///
  /// In en, this message translates to:
  /// **'AI {status}; AI rows {aiRows}; local-rule rows {localRows}.'**
  String importJobSummaryAiLine(String status, int aiRows, int localRows);

  /// No description provided for @importJobSummaryCategoriesLine.
  ///
  /// In en, this message translates to:
  /// **'Best-guess categories {misc}; category update failures {failures}.'**
  String importJobSummaryCategoriesLine(int misc, int failures);

  /// No description provided for @importJobSummaryScannedLine.
  ///
  /// In en, this message translates to:
  /// **'Scanned {scanned}; retryable {retryable}.'**
  String importJobSummaryScannedLine(int scanned, int retryable);

  /// No description provided for @importJobSummaryUpdatedLine.
  ///
  /// In en, this message translates to:
  /// **'Updated {updated}; still uncategorized {remaining}.'**
  String importJobSummaryUpdatedLine(int updated, int remaining);

  /// No description provided for @importJobAiStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get importJobAiStatusCompleted;

  /// No description provided for @importJobAiStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get importJobAiStatusUnavailable;

  /// No description provided for @mfaEnrollmentAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-factor authentication'**
  String get mfaEnrollmentAppBarTitle;

  /// No description provided for @mfaEnrollmentTurnOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off MFA?'**
  String get mfaEnrollmentTurnOffTitle;

  /// No description provided for @mfaEnrollmentCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mfaEnrollmentCancel;

  /// No description provided for @mfaEnrollmentTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get mfaEnrollmentTurnOff;

  /// No description provided for @mfaEnrollmentAuthenticatorApps.
  ///
  /// In en, this message translates to:
  /// **'Authenticator apps'**
  String get mfaEnrollmentAuthenticatorApps;

  /// No description provided for @mfaEnrollmentMfaOn.
  ///
  /// In en, this message translates to:
  /// **'MFA is on'**
  String get mfaEnrollmentMfaOn;

  /// No description provided for @mfaEnrollmentMfaOff.
  ///
  /// In en, this message translates to:
  /// **'MFA is off'**
  String get mfaEnrollmentMfaOff;

  /// No description provided for @mfaEnrollmentTurnOnMfa.
  ///
  /// In en, this message translates to:
  /// **'Turn on MFA'**
  String get mfaEnrollmentTurnOnMfa;

  /// No description provided for @mfaEnrollmentSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up authenticator app'**
  String get mfaEnrollmentSetupTitle;

  /// No description provided for @mfaEnrollmentCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get mfaEnrollmentCodeLabel;

  /// No description provided for @mfaEnrollmentEnableMfa.
  ///
  /// In en, this message translates to:
  /// **'Enable MFA'**
  String get mfaEnrollmentEnableMfa;

  /// No description provided for @mfaVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your MFA code'**
  String get mfaVerificationTitle;

  /// No description provided for @mfaVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open your authenticator app and enter the current 6-digit code for Clarity.'**
  String get mfaVerificationSubtitle;

  /// No description provided for @mfaVerificationAuthenticatorAppLabel.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app'**
  String get mfaVerificationAuthenticatorAppLabel;

  /// No description provided for @mfaVerificationVerifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get mfaVerificationVerifyAndContinue;

  /// No description provided for @mfaEnterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code.'**
  String get mfaEnterSixDigitCode;

  /// No description provided for @mfaEnrollmentTurnOffBodySingle.
  ///
  /// In en, this message translates to:
  /// **'Your account will no longer ask for an authenticator code after password sign-in.'**
  String get mfaEnrollmentTurnOffBodySingle;

  /// No description provided for @mfaEnrollmentTurnOffBodyMultiple.
  ///
  /// In en, this message translates to:
  /// **'This removes all {factorCount} authenticator apps. Your account will no longer ask for an authenticator code after password sign-in.'**
  String mfaEnrollmentTurnOffBodyMultiple(int factorCount);

  /// No description provided for @mfaEnrollmentRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove MFA?'**
  String get mfaEnrollmentRemoveTitle;

  /// No description provided for @mfaEnrollmentRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {factorName}? You can enroll another authenticator app later.'**
  String mfaEnrollmentRemoveBody(String factorName);

  /// No description provided for @mfaEnrollmentAddAnotherApp.
  ///
  /// In en, this message translates to:
  /// **'Add another app'**
  String get mfaEnrollmentAddAnotherApp;

  /// No description provided for @mfaEnrollmentMfaOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account requires an authenticator code after password sign-in.'**
  String get mfaEnrollmentMfaOnDescription;

  /// No description provided for @mfaEnrollmentMfaOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Add an authenticator app to protect your financial workspace.'**
  String get mfaEnrollmentMfaOffDescription;

  /// No description provided for @mfaEnrollmentSetupInstructions.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code in 1Password, Google Authenticator, Authy, or another TOTP app.'**
  String get mfaEnrollmentSetupInstructions;

  /// No description provided for @mfaEnrollmentCopyAuthenticatorUri.
  ///
  /// In en, this message translates to:
  /// **'Copy authenticator URI'**
  String get mfaEnrollmentCopyAuthenticatorUri;

  /// No description provided for @mfaEnrollmentManualSetupKey.
  ///
  /// In en, this message translates to:
  /// **'Manual setup key'**
  String get mfaEnrollmentManualSetupKey;

  /// No description provided for @mfaEnrollmentCopyManualSetupKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy manual setup key'**
  String get mfaEnrollmentCopyManualSetupKeyTooltip;

  /// No description provided for @mfaEnrollmentRemoveAuthenticatorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove authenticator app'**
  String get mfaEnrollmentRemoveAuthenticatorTooltip;

  /// No description provided for @mfaEnrollmentRecoveryNotice.
  ///
  /// In en, this message translates to:
  /// **'Supabase Auth does not provide recovery codes for TOTP. Add a second authenticator app as a backup before removing your only factor.'**
  String get mfaEnrollmentRecoveryNotice;

  /// No description provided for @mfaEnrollmentManualSetupKeyCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual setup key'**
  String get mfaEnrollmentManualSetupKeyCopyLabel;

  /// No description provided for @mfaEnrollmentAuthenticatorUriCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'Authenticator URI'**
  String get mfaEnrollmentAuthenticatorUriCopyLabel;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect. Try again or create a new account.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead.'**
  String get authErrorAccountExists;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email first, then sign in.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorEmailSendFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not send a confirmation email right now. Try again in a few minutes or contact support if this continues.'**
  String get authErrorEmailSendFailed;

  /// No description provided for @authErrorSignupsDisabled.
  ///
  /// In en, this message translates to:
  /// **'New account sign-up is disabled for this app right now.'**
  String get authErrorSignupsDisabled;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password and try again.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorMfaCodeRejected.
  ///
  /// In en, this message translates to:
  /// **'That code was not accepted. Check your authenticator app and try again.'**
  String get authErrorMfaCodeRejected;

  /// No description provided for @authErrorMfaNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'MFA is not enabled for this Supabase project.'**
  String get authErrorMfaNotEnabled;

  /// No description provided for @authErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment, then try again.'**
  String get authErrorTooManyAttempts;

  /// No description provided for @authErrorNoAuthenticatorAvailable.
  ///
  /// In en, this message translates to:
  /// **'No verified authenticator app is available for this account.'**
  String get authErrorNoAuthenticatorAvailable;

  /// No description provided for @authErrorStartEnrollmentFirst.
  ///
  /// In en, this message translates to:
  /// **'Start MFA enrollment before verifying a code.'**
  String get authErrorStartEnrollmentFirst;

  /// No description provided for @authInfoAccountCreatedSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Account created. You are signed in.'**
  String get authInfoAccountCreatedSignedIn;

  /// No description provided for @authInfoConfirmationLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it to confirm, then come back here and sign in.'**
  String authInfoConfirmationLinkSent(String email);

  /// No description provided for @authInfoEnterAuthenticatorCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your authenticator code to finish signing in.'**
  String get authInfoEnterAuthenticatorCode;

  /// No description provided for @authInfoPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we sent a password reset link.'**
  String authInfoPasswordResetSent(String email);

  /// No description provided for @authInfoMfaEnrollmentStart.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code, then enter the 6-digit code from your app.'**
  String get authInfoMfaEnrollmentStart;

  /// No description provided for @authInfoMfaEnabledEmailSent.
  ///
  /// In en, this message translates to:
  /// **'MFA is enabled. We sent you a confirmation email.'**
  String get authInfoMfaEnabledEmailSent;

  /// No description provided for @authInfoMfaEnabledEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'MFA is enabled. Confirmation email could not be sent right now.'**
  String get authInfoMfaEnabledEmailFailed;

  /// No description provided for @authInfoMfaDisabledEmailSent.
  ///
  /// In en, this message translates to:
  /// **'MFA is off. We sent you a confirmation email.'**
  String get authInfoMfaDisabledEmailSent;

  /// No description provided for @authInfoMfaDisabledEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'MFA is off. Confirmation email could not be sent right now.'**
  String get authInfoMfaDisabledEmailFailed;

  /// No description provided for @authInfoSignInVerified.
  ///
  /// In en, this message translates to:
  /// **'Sign-in verified.'**
  String get authInfoSignInVerified;

  /// No description provided for @authInfoAuthenticatorRemoved.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app removed.'**
  String get authInfoAuthenticatorRemoved;

  /// No description provided for @authInfoMfaAlreadyOff.
  ///
  /// In en, this message translates to:
  /// **'MFA is already off.'**
  String get authInfoMfaAlreadyOff;

  /// No description provided for @importProgressImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importProgressImporting;

  /// No description provided for @importProgressCategorizing.
  ///
  /// In en, this message translates to:
  /// **'Categorizing...'**
  String get importProgressCategorizing;

  /// No description provided for @importProgressSavingCategories.
  ///
  /// In en, this message translates to:
  /// **'Saving categories...'**
  String get importProgressSavingCategories;

  /// No description provided for @importProgressApplyingFallbackCategories.
  ///
  /// In en, this message translates to:
  /// **'Applying fallback categories...'**
  String get importProgressApplyingFallbackCategories;

  /// No description provided for @importProgressRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get importProgressRefreshing;

  /// No description provided for @usageChartNoDailyVoiceUsage.
  ///
  /// In en, this message translates to:
  /// **'No daily voice usage yet.'**
  String get usageChartNoDailyVoiceUsage;

  /// No description provided for @usageChartNotEnoughRadarData.
  ///
  /// In en, this message translates to:
  /// **'Not enough usage data for radar chart.'**
  String get usageChartNotEnoughRadarData;

  /// No description provided for @usageChartNoDailyCallData.
  ///
  /// In en, this message translates to:
  /// **'No daily call data yet.'**
  String get usageChartNoDailyCallData;

  /// No description provided for @usageChartDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get usageChartDayMon;

  /// No description provided for @usageChartDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get usageChartDayTue;

  /// No description provided for @usageChartDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get usageChartDayWed;

  /// No description provided for @usageChartDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get usageChartDayThu;

  /// No description provided for @usageChartDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get usageChartDayFri;

  /// No description provided for @usageChartDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get usageChartDaySat;

  /// No description provided for @usageChartDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get usageChartDaySun;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @dashboardBudgetNoBudgetsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No budgets set for {periodLabel} yet.'**
  String dashboardBudgetNoBudgetsForPeriod(String periodLabel);

  /// No description provided for @dashboardBudgetCategoriesOnTrack.
  ///
  /// In en, this message translates to:
  /// **'{onTrack}/{budgeted} categories on track'**
  String dashboardBudgetCategoriesOnTrack(int onTrack, int budgeted);

  /// No description provided for @dashboardBudgetTotalOverspent.
  ///
  /// In en, this message translates to:
  /// **'Total overspent {amount}'**
  String dashboardBudgetTotalOverspent(String amount);

  /// No description provided for @dashboardBudgetBudgetedSpentLine.
  ///
  /// In en, this message translates to:
  /// **'Budgeted {budgeted} / Spent {spent}'**
  String dashboardBudgetBudgetedSpentLine(String budgeted, String spent);

  /// No description provided for @dashboardBudgetNoOverspendingCategories.
  ///
  /// In en, this message translates to:
  /// **'No overspending categories in this period.'**
  String get dashboardBudgetNoOverspendingCategories;

  /// No description provided for @dashboardBudgetCategoryOverspent.
  ///
  /// In en, this message translates to:
  /// **'{label}: overspent {amount}'**
  String dashboardBudgetCategoryOverspent(String label, String amount);

  /// No description provided for @dashboardHealthSpendingAheadOfIncome.
  ///
  /// In en, this message translates to:
  /// **'Spending is ahead of income by {amount} this month.'**
  String dashboardHealthSpendingAheadOfIncome(String amount);

  /// No description provided for @dashboardHealthIncomeAheadOfSpending.
  ///
  /// In en, this message translates to:
  /// **'Income is ahead of spending by {amount} this month.'**
  String dashboardHealthIncomeAheadOfSpending(String amount);

  /// No description provided for @dashboardHealthSpendingActiveNoIncome.
  ///
  /// In en, this message translates to:
  /// **'Spending is active this month; no income is recorded in this scope.'**
  String get dashboardHealthSpendingActiveNoIncome;

  /// No description provided for @dashboardHealthIncomeNoSpending.
  ///
  /// In en, this message translates to:
  /// **'Income is recorded and no spending has posted for this month yet.'**
  String get dashboardHealthIncomeNoSpending;

  /// No description provided for @dashboardHealthNoCurrentMonthActivity.
  ///
  /// In en, this message translates to:
  /// **'No current-month activity in this scope yet.'**
  String get dashboardHealthNoCurrentMonthActivity;

  /// No description provided for @dashboardHealthConnectTransactions.
  ///
  /// In en, this message translates to:
  /// **'Connect transactions to build account health.'**
  String get dashboardHealthConnectTransactions;

  /// No description provided for @dashboardHealthNoBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets'**
  String get dashboardHealthNoBudgets;

  /// No description provided for @dashboardHealthSetBudgets.
  ///
  /// In en, this message translates to:
  /// **'Set budgets to compare this month against a target.'**
  String get dashboardHealthSetBudgets;

  /// No description provided for @dashboardHealthCategoryOverBy.
  ///
  /// In en, this message translates to:
  /// **'{label} is over by {amount}.'**
  String dashboardHealthCategoryOverBy(String label, String amount);

  /// No description provided for @dashboardHealthBudgetControlled.
  ///
  /// In en, this message translates to:
  /// **'Budget coverage looks controlled for {periodLabel}.'**
  String dashboardHealthBudgetControlled(String periodLabel);

  /// No description provided for @dashboardHealthNoSpendingPressure.
  ///
  /// In en, this message translates to:
  /// **'No spending pressure recorded this month.'**
  String get dashboardHealthNoSpendingPressure;

  /// No description provided for @dashboardHealthTopSpendPressure.
  ///
  /// In en, this message translates to:
  /// **'{name} is the largest spend pressure this month.'**
  String dashboardHealthTopSpendPressure(String name);

  /// No description provided for @dashboardHealthThisMonthNet.
  ///
  /// In en, this message translates to:
  /// **'This month net'**
  String get dashboardHealthThisMonthNet;

  /// No description provided for @dashboardHealthSpendPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Spend pressure'**
  String get dashboardHealthSpendPressureLabel;

  /// No description provided for @dashboardHealthBudgetCoverageLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget coverage'**
  String get dashboardHealthBudgetCoverageLabel;

  /// No description provided for @dashboardHealthBurnRunwayLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash runway'**
  String get dashboardHealthBurnRunwayLabel;

  /// No description provided for @dashboardHealthBurnRunwayDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String dashboardHealthBurnRunwayDays(int days);

  /// No description provided for @dashboardHealthBurnRunwayDetail.
  ///
  /// In en, this message translates to:
  /// **'At this month\'s spending pace, your balance lasts about {days} days.'**
  String dashboardHealthBurnRunwayDetail(int days);

  /// No description provided for @dashboardOverviewBudgetVsSpentChart.
  ///
  /// In en, this message translates to:
  /// **'Budget vs spent'**
  String get dashboardOverviewBudgetVsSpentChart;

  /// No description provided for @dashboardHealthIncomeSpendingLine.
  ///
  /// In en, this message translates to:
  /// **'Income {income} / Spending {spending}'**
  String dashboardHealthIncomeSpendingLine(String income, String spending);

  /// No description provided for @dashboardChartConnectAccountsCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Connect accounts to see monthly cash flow.'**
  String get dashboardChartConnectAccountsCashFlow;

  /// No description provided for @dashboardChartNoCategorySpending.
  ///
  /// In en, this message translates to:
  /// **'No category spending yet.'**
  String get dashboardChartNoCategorySpending;

  /// No description provided for @dashboardChartNoSpendingPressure.
  ///
  /// In en, this message translates to:
  /// **'No spending pressure this month.'**
  String get dashboardChartNoSpendingPressure;

  /// No description provided for @dashboardChartNoBudgetCategories.
  ///
  /// In en, this message translates to:
  /// **'No budget categories to chart.'**
  String get dashboardChartNoBudgetCategories;

  /// No description provided for @dashboardChartNoSpendingHistory.
  ///
  /// In en, this message translates to:
  /// **'No spending history yet.'**
  String get dashboardChartNoSpendingHistory;

  /// No description provided for @dashboardChartNoIncomeOrSpending.
  ///
  /// In en, this message translates to:
  /// **'No income or spending this month.'**
  String get dashboardChartNoIncomeOrSpending;

  /// No description provided for @dashboardChartIncomeSpendingSummary.
  ///
  /// In en, this message translates to:
  /// **'Income {income} · Spending {spent}'**
  String dashboardChartIncomeSpendingSummary(String income, String spent);

  /// No description provided for @monthDetailDeleteMonthTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete this month'**
  String get monthDetailDeleteMonthTooltip;

  /// No description provided for @monthDetailDeleteMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {monthLabel} transactions?'**
  String monthDetailDeleteMonthTitle(String monthLabel);

  /// No description provided for @monthDetailDeleteMonthBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the {count} visible transaction{transactionSuffix} for this account in {monthLabel}. Other months will stay untouched.'**
  String monthDetailDeleteMonthBody(
    int count,
    String transactionSuffix,
    String monthLabel,
  );

  /// No description provided for @monthDetailDeleteMonthButton.
  ///
  /// In en, this message translates to:
  /// **'Delete month'**
  String get monthDetailDeleteMonthButton;

  /// No description provided for @monthDetailDeletedTransactions.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} {monthLabel} transaction{transactionSuffix}.'**
  String monthDetailDeletedTransactions(
    int count,
    String monthLabel,
    String transactionSuffix,
  );

  /// No description provided for @monthDetailNothingDeleted.
  ///
  /// In en, this message translates to:
  /// **'No transactions were deleted.'**
  String get monthDetailNothingDeleted;

  /// No description provided for @monthDetailLoadingMonth.
  ///
  /// In en, this message translates to:
  /// **'Loading month'**
  String get monthDetailLoadingMonth;

  /// No description provided for @monthDetailNetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'NET THIS MONTH'**
  String get monthDetailNetThisMonth;

  /// No description provided for @monthDetailNoTransactionsLeft.
  ///
  /// In en, this message translates to:
  /// **'No transactions left for this month.'**
  String get monthDetailNoTransactionsLeft;

  /// No description provided for @monthDetailDeleteTransactionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get monthDetailDeleteTransactionTooltip;

  /// No description provided for @monthDetailDeleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get monthDetailDeleteTransactionTitle;

  /// No description provided for @monthDetailDeleteTransactionBody.
  ///
  /// In en, this message translates to:
  /// **'This transaction will be permanently deleted.'**
  String get monthDetailDeleteTransactionBody;

  /// No description provided for @monthDetailTransactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted.'**
  String get monthDetailTransactionDeleted;

  /// No description provided for @monthDetailDeleteTransactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete transaction.'**
  String get monthDetailDeleteTransactionFailed;

  /// No description provided for @monthDetailPlaidDeleteProtection.
  ///
  /// In en, this message translates to:
  /// **'Plaid transactions sync from your bank. Use resync or disconnect instead of local deletion.'**
  String get monthDetailPlaidDeleteProtection;

  /// No description provided for @accountsScreenNoActiveConnectionRefresh.
  ///
  /// In en, this message translates to:
  /// **'No active bank connection to refresh.'**
  String get accountsScreenNoActiveConnectionRefresh;

  /// No description provided for @accountsScreenCouldNotRefreshAccounts.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh connected accounts.'**
  String get accountsScreenCouldNotRefreshAccounts;

  /// No description provided for @accountsScreenDisconnectedConnection.
  ///
  /// In en, this message translates to:
  /// **'This bank connection is disconnected.'**
  String get accountsScreenDisconnectedConnection;

  /// No description provided for @accountsScreenCouldNotRefreshAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh this account.'**
  String get accountsScreenCouldNotRefreshAccount;

  /// No description provided for @accountsScreenCouldNotDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect this bank.'**
  String get accountsScreenCouldNotDisconnect;

  /// No description provided for @accountsScreenDisconnectedNotice.
  ///
  /// In en, this message translates to:
  /// **'{institutionName} disconnected. Future Plaid sync is stopped.'**
  String accountsScreenDisconnectedNotice(String institutionName);

  /// No description provided for @plaidAccountStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get plaidAccountStatusConnected;

  /// No description provided for @plaidAccountStatusDegradedLabel.
  ///
  /// In en, this message translates to:
  /// **'Degraded'**
  String get plaidAccountStatusDegradedLabel;

  /// No description provided for @plaidAccountStatusNeedsLogin.
  ///
  /// In en, this message translates to:
  /// **'Needs login'**
  String get plaidAccountStatusNeedsLogin;

  /// No description provided for @plaidAccountStatusRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing this bank connection now.'**
  String get plaidAccountStatusRefreshing;

  /// No description provided for @plaidAccountStatusDegradedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync needs attention. Try refresh; if it still fails, reconnect this bank in Plaid.'**
  String get plaidAccountStatusDegradedMessage;

  /// No description provided for @plaidAccountStatusLoginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Plaid needs you to sign in again. Connect this bank again to resume sync.'**
  String get plaidAccountStatusLoginRequiredMessage;

  /// No description provided for @plaidAccountStatusExpiringSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'This Plaid connection may expire soon. Refresh now or reconnect if sync stops.'**
  String get plaidAccountStatusExpiringSoonMessage;

  /// No description provided for @plaidAccountStatusDisconnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Future Plaid sync is stopped. Existing account history stays in Clarity.'**
  String get plaidAccountStatusDisconnectedMessage;

  /// No description provided for @plaidAccountNoWebhookYet.
  ///
  /// In en, this message translates to:
  /// **'No Plaid webhook has arrived yet. Use refresh if transactions look stale.'**
  String get plaidAccountNoWebhookYet;

  /// No description provided for @plaidAccountNoRecentWebhook.
  ///
  /// In en, this message translates to:
  /// **'No recent Plaid webhook. Last bank update signal was {relativeTime}.'**
  String plaidAccountNoRecentWebhook(String relativeTime);

  /// No description provided for @plaidAccountWebhookDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String plaidAccountWebhookDaysAgo(int days);

  /// No description provided for @plaidAccountWebhookHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String plaidAccountWebhookHoursAgo(int hours);

  /// No description provided for @plaidAccountWebhookMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String plaidAccountWebhookMinutesAgo(int minutes);

  /// No description provided for @plaidAccountWebhookJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get plaidAccountWebhookJustNow;

  /// No description provided for @accountDetailNoCsvUploads.
  ///
  /// In en, this message translates to:
  /// **'No CSV uploads found for this account.'**
  String get accountDetailNoCsvUploads;

  /// No description provided for @accountDetailDeleteCsvBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} transaction{transactionSuffix} from this upload? This cannot be undone.'**
  String accountDetailDeleteCsvBody(int count, String transactionSuffix);

  /// No description provided for @accountDetailDeletedFromCsv.
  ///
  /// In en, this message translates to:
  /// **'Deleted {deleted} transaction{transactionSuffix} from CSV upload.'**
  String accountDetailDeletedFromCsv(int deleted, String transactionSuffix);

  /// No description provided for @accountDetailCsvAlreadyDeleted.
  ///
  /// In en, this message translates to:
  /// **'CSV upload was already deleted.'**
  String get accountDetailCsvAlreadyDeleted;

  /// No description provided for @accountDetailCouldNotDeleteCsv.
  ///
  /// In en, this message translates to:
  /// **'Could not delete CSV upload.'**
  String get accountDetailCouldNotDeleteCsv;

  /// No description provided for @accountDetailCouldNotDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account.'**
  String get accountDetailCouldNotDeleteAccount;

  /// No description provided for @accountDetailAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'{accountName} deleted.{cleanupNote}'**
  String accountDetailAccountDeleted(String accountName, String cleanupNote);

  /// No description provided for @accountDetailRemovedBudgets.
  ///
  /// In en, this message translates to:
  /// **' Removed {count} unused budget{budgetSuffix}.'**
  String accountDetailRemovedBudgets(int count, String budgetSuffix);

  /// No description provided for @accountDetailDeleteUnusedCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete unused custom {plural}?'**
  String accountDetailDeleteUnusedCategoryTitle(String plural);

  /// No description provided for @accountDetailDeleteUnusedCategorySingle.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" no longer has active transactions after deleting this account. Delete this custom category too?'**
  String accountDetailDeleteUnusedCategorySingle(String name);

  /// No description provided for @accountDetailDeleteUnusedCategoryMultiple.
  ///
  /// In en, this message translates to:
  /// **'These custom categories no longer have active transactions after deleting this account: {names}. Delete them too?'**
  String accountDetailDeleteUnusedCategoryMultiple(String names);

  /// No description provided for @accountDetailUploadBatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload {importId}'**
  String accountDetailUploadBatchLabel(String importId);

  /// No description provided for @accountDetailCategorySingular.
  ///
  /// In en, this message translates to:
  /// **'category'**
  String get accountDetailCategorySingular;

  /// No description provided for @accountDetailCategoriesPlural.
  ///
  /// In en, this message translates to:
  /// **'categories'**
  String get accountDetailCategoriesPlural;

  /// No description provided for @csvPreviewPlaidOverlapHint.
  ///
  /// In en, this message translates to:
  /// **'This connected account already syncs through Plaid. Import only if this CSV covers rows Clarity does not have yet.'**
  String get csvPreviewPlaidOverlapHint;

  /// No description provided for @csvPreviewManualFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'This is a manual fallback import. You may need to upload newer CSV files later to keep this account current.'**
  String get csvPreviewManualFallbackHint;

  /// No description provided for @csvPreviewLayoutInferred.
  ///
  /// In en, this message translates to:
  /// **'Column layout was inferred. Review the date range before importing.'**
  String get csvPreviewLayoutInferred;

  /// No description provided for @csvPreviewDuplicateImport.
  ///
  /// In en, this message translates to:
  /// **'This looks like a duplicate import for this account. Choose another account, or delete the previous CSV upload from the account page before retrying.'**
  String get csvPreviewDuplicateImport;

  /// No description provided for @accountSelectionManualAccountForCsv.
  ///
  /// In en, this message translates to:
  /// **'Add a manual account for this CSV'**
  String get accountSelectionManualAccountForCsv;

  /// No description provided for @assistantTabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get assistantTabChat;

  /// No description provided for @assistantTabKnows.
  ///
  /// In en, this message translates to:
  /// **'Knows'**
  String get assistantTabKnows;

  /// No description provided for @assistantTabGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get assistantTabGoals;

  /// No description provided for @assistantTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get assistantTabOverview;

  /// No description provided for @assistantTabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get assistantTabChats;

  /// No description provided for @assistantOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Companion overview'**
  String get assistantOverviewTitle;

  /// No description provided for @assistantOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rules, patterns, open threads, and goals Rex is tracking with you.'**
  String get assistantOverviewSubtitle;

  /// No description provided for @assistantOverviewBrowseChats.
  ///
  /// In en, this message translates to:
  /// **'Browse chats'**
  String get assistantOverviewBrowseChats;

  /// No description provided for @assistantChatSidebarHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide chats'**
  String get assistantChatSidebarHideTooltip;

  /// No description provided for @assistantChatSidebarShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show chats'**
  String get assistantChatSidebarShowTooltip;

  /// No description provided for @assistantOverviewAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'What to watch'**
  String get assistantOverviewAttentionTitle;

  /// No description provided for @assistantOverviewAttentionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs attention right now.'**
  String get assistantOverviewAttentionEmpty;

  /// No description provided for @assistantOverviewRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Active rules'**
  String get assistantOverviewRulesTitle;

  /// No description provided for @assistantOverviewRulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active rules yet. Save one in Knows or ask Rex.'**
  String get assistantOverviewRulesEmpty;

  /// No description provided for @assistantOverviewThreadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open threads'**
  String get assistantOverviewThreadsTitle;

  /// No description provided for @assistantOverviewThreadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open threads. Habits and check-ins will show here.'**
  String get assistantOverviewThreadsEmpty;

  /// No description provided for @assistantOverviewGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active goals'**
  String get assistantOverviewGoalsTitle;

  /// No description provided for @assistantOverviewGoalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active goals yet. Add one in Goals or ask Rex.'**
  String get assistantOverviewGoalsEmpty;

  /// No description provided for @assistantTabSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistant {tab} tab'**
  String assistantTabSemanticLabel(String tab);

  /// No description provided for @voicePanelVoiceMuted.
  ///
  /// In en, this message translates to:
  /// **'Voice muted'**
  String get voicePanelVoiceMuted;

  /// No description provided for @voicePanelVoiceReady.
  ///
  /// In en, this message translates to:
  /// **'Voice ready'**
  String get voicePanelVoiceReady;

  /// No description provided for @voicePanelListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get voicePanelListening;

  /// No description provided for @voicePanelThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get voicePanelThinking;

  /// No description provided for @voicePanelSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get voicePanelSpeaking;

  /// No description provided for @voicePanelVoicePaused.
  ///
  /// In en, this message translates to:
  /// **'Voice paused'**
  String get voicePanelVoicePaused;

  /// No description provided for @voiceSessionReturnToChat.
  ///
  /// In en, this message translates to:
  /// **'Return to Assistant chat'**
  String get voiceSessionReturnToChat;

  /// No description provided for @voiceFailureSessionReconnect.
  ///
  /// In en, this message translates to:
  /// **'Your Clarity session needs to reconnect before voice can continue. Sign in again if this keeps happening.'**
  String get voiceFailureSessionReconnect;

  /// No description provided for @voiceFailureMicrophoneAccess.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed for voice. Check Settings, then try again.'**
  String get voiceFailureMicrophoneAccess;

  /// No description provided for @voiceFailureDidNotCatch.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch that. Tap Try again when you are ready.'**
  String get voiceFailureDidNotCatch;

  /// No description provided for @voiceFailureConnectionDropped.
  ///
  /// In en, this message translates to:
  /// **'Voice connection dropped. Tap Try again to reconnect.'**
  String get voiceFailureConnectionDropped;

  /// No description provided for @voiceFailureTranscriptUnreadable.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t read that transcript. Tap Try again and say it once more.'**
  String get voiceFailureTranscriptUnreadable;

  /// No description provided for @voiceFailurePlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Rex answered, but I couldn\'t play the audio. Tap Try again to hear the reply.'**
  String get voiceFailurePlaybackFailed;

  /// No description provided for @voiceFailurePausedDefault.
  ///
  /// In en, this message translates to:
  /// **'Voice paused. Tap Try again when you are ready to continue.'**
  String get voiceFailurePausedDefault;

  /// No description provided for @memoryHeaderEmptyActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Add something here, or ask Rex in chat or voice to save it.'**
  String get memoryHeaderEmptyActiveBody;

  /// No description provided for @memoryHeaderEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Saved facts, people, and preferences will appear here.'**
  String get memoryHeaderEmptyBody;

  /// No description provided for @memoryHeaderEmptyAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add saved information'**
  String get memoryHeaderEmptyAddAction;

  /// No description provided for @memoryHeaderNoMatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching information'**
  String get memoryHeaderNoMatchingTitle;

  /// No description provided for @memoryHeaderNoMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'Try another search or filter.'**
  String get memoryHeaderNoMatchingBody;

  /// No description provided for @memoryPagePersonUpdated.
  ///
  /// In en, this message translates to:
  /// **'Person updated'**
  String get memoryPagePersonUpdated;

  /// No description provided for @memoryPageRuleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Rule updated'**
  String get memoryPageRuleUpdated;

  /// No description provided for @memoryPagePlanUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plan updated'**
  String get memoryPagePlanUpdated;

  /// No description provided for @memoryCreateAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add saved information'**
  String get memoryCreateAddTooltip;

  /// No description provided for @memoryCreateChooseType.
  ///
  /// In en, this message translates to:
  /// **'What should Clarity remember?'**
  String get memoryCreateChooseType;

  /// No description provided for @memoryCreateFact.
  ///
  /// In en, this message translates to:
  /// **'Fact'**
  String get memoryCreateFact;

  /// No description provided for @memoryCreatePreference.
  ///
  /// In en, this message translates to:
  /// **'Preference'**
  String get memoryCreatePreference;

  /// No description provided for @memoryCreateRule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get memoryCreateRule;

  /// No description provided for @memoryCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get memoryCreatePlan;

  /// No description provided for @memoryCreateFactTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a fact'**
  String get memoryCreateFactTitle;

  /// No description provided for @memoryCreatePreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a preference'**
  String get memoryCreatePreferenceTitle;

  /// No description provided for @memoryCreatePersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a person'**
  String get memoryCreatePersonTitle;

  /// No description provided for @memoryCreateRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a rule'**
  String get memoryCreateRuleTitle;

  /// No description provided for @memoryCreatePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a plan'**
  String get memoryCreatePlanTitle;

  /// No description provided for @memoryCreateCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get memoryCreateCategoryLabel;

  /// No description provided for @memoryCreateRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get memoryCreateRelationshipLabel;

  /// No description provided for @memoryCreateSave.
  ///
  /// In en, this message translates to:
  /// **'Save to Knows'**
  String get memoryCreateSave;

  /// No description provided for @memoryPageMemoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Saved to Knows'**
  String get memoryPageMemoryCreated;

  /// No description provided for @memoryPagePersonCreated.
  ///
  /// In en, this message translates to:
  /// **'Person saved'**
  String get memoryPagePersonCreated;

  /// No description provided for @memoryPageRuleCreated.
  ///
  /// In en, this message translates to:
  /// **'Rule saved'**
  String get memoryPageRuleCreated;

  /// No description provided for @memoryPagePlanCreated.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get memoryPagePlanCreated;

  /// No description provided for @memoryPageMilestoneCreated.
  ///
  /// In en, this message translates to:
  /// **'Milestone saved'**
  String get memoryPageMilestoneCreated;

  /// No description provided for @memoryPageMilestoneUpdated.
  ///
  /// In en, this message translates to:
  /// **'Milestone updated'**
  String get memoryPageMilestoneUpdated;

  /// No description provided for @memoryCreateMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a milestone'**
  String get memoryCreateMilestoneTitle;

  /// No description provided for @memoryEditEditMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit milestone'**
  String get memoryEditEditMilestoneTitle;

  /// No description provided for @memoryEditEditPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get memoryEditEditPersonTitle;

  /// No description provided for @memoryEditPersonRelationshipHint.
  ///
  /// In en, this message translates to:
  /// **'Relationship — e.g. friend, coworker, sister'**
  String get memoryEditPersonRelationshipHint;

  /// No description provided for @memoryEditPersonRelationshipHelper.
  ///
  /// In en, this message translates to:
  /// **'Clarity uses this as the relationship type.'**
  String get memoryEditPersonRelationshipHelper;

  /// No description provided for @memoryEditPersonBirthdayHint.
  ///
  /// In en, this message translates to:
  /// **'mm/dd/yyyy'**
  String get memoryEditPersonBirthdayHint;

  /// No description provided for @memoryEditPersonDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from Knows? This archives the person card.'**
  String memoryEditPersonDeleteBody(String name);

  /// No description provided for @memoryEditEditRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get memoryEditEditRuleTitle;

  /// No description provided for @memoryEditEditPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get memoryEditEditPlanTitle;

  /// No description provided for @memoryEditRuleTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule text'**
  String get memoryEditRuleTextLabel;

  /// No description provided for @memoryEditTriggerKeywordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Trigger keywords'**
  String get memoryEditTriggerKeywordsLabel;

  /// No description provided for @memoryEditDesiredOutcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Desired outcome'**
  String get memoryEditDesiredOutcomeLabel;

  /// No description provided for @memoryEditAliasesLabel.
  ///
  /// In en, this message translates to:
  /// **'Aliases'**
  String get memoryEditAliasesLabel;

  /// No description provided for @memoryArchiveNamedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {label}?'**
  String memoryArchiveNamedTitle(String label);

  /// No description provided for @memoryArchiveStructuredBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this {label} from Knows? Rex will stop using it as active context.'**
  String memoryArchiveStructuredBody(String label);

  /// No description provided for @memoryDisplayLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get memoryDisplayLocation;

  /// No description provided for @memoryDisplayBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get memoryDisplayBirthday;

  /// No description provided for @memoryDisplayJob.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get memoryDisplayJob;

  /// No description provided for @memoryDisplayWorkplace.
  ///
  /// In en, this message translates to:
  /// **'Workplace'**
  String get memoryDisplayWorkplace;

  /// No description provided for @memoryDisplayImportantDate.
  ///
  /// In en, this message translates to:
  /// **'Important date'**
  String get memoryDisplayImportantDate;

  /// No description provided for @accountabilityAddGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get accountabilityAddGoalTitle;

  /// No description provided for @accountabilityAddOpenThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Add open thread'**
  String get accountabilityAddOpenThreadTitle;

  /// No description provided for @accountabilityAddGoalPrimaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal title'**
  String get accountabilityAddGoalPrimaryLabel;

  /// No description provided for @accountabilityAddOpenThreadPrimaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Open thread title'**
  String get accountabilityAddOpenThreadPrimaryLabel;

  /// No description provided for @accountabilityAddGoalPrimaryHint.
  ///
  /// In en, this message translates to:
  /// **'Build a reliable morning routine'**
  String get accountabilityAddGoalPrimaryHint;

  /// No description provided for @accountabilityAddGoalDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Wake up at 5 AM and start the day cleanly'**
  String get accountabilityAddGoalDetailHint;

  /// No description provided for @accountabilityAddOpenThreadPrimaryHint.
  ///
  /// In en, this message translates to:
  /// **'Wake up at 5 AM'**
  String get accountabilityAddOpenThreadPrimaryHint;

  /// No description provided for @accountabilityAddOpenThreadDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Wake up at 5 AM and start my morning routine'**
  String get accountabilityAddOpenThreadDetailHint;

  /// No description provided for @accountabilityGoalSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal saved.'**
  String get accountabilityGoalSaved;

  /// No description provided for @accountabilityOpenThreadSaved.
  ///
  /// In en, this message translates to:
  /// **'Open thread saved.'**
  String get accountabilityOpenThreadSaved;

  /// No description provided for @accountabilityOpenThreadMaxActive.
  ///
  /// In en, this message translates to:
  /// **'You can have at most {count} active open threads. Close or pause one before adding another.'**
  String accountabilityOpenThreadMaxActive(int count);

  /// No description provided for @accountabilityOpenThreadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Open thread completed.'**
  String get accountabilityOpenThreadCompleted;

  /// No description provided for @accountabilityMarkMissedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark missed?'**
  String get accountabilityMarkMissedTitle;

  /// No description provided for @accountabilityMarkMissedBody.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as missed? It will leave your active Goals list.'**
  String accountabilityMarkMissedBody(String title);

  /// No description provided for @accountabilityArchiveOpenThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete open thread?'**
  String get accountabilityArchiveOpenThreadTitle;

  /// No description provided for @accountabilityArchiveOpenThreadBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? It will leave your active Goals list.'**
  String accountabilityArchiveOpenThreadBody(String title);

  /// No description provided for @accountabilityArchiveGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete goal?'**
  String get accountabilityArchiveGoalTitle;

  /// No description provided for @accountabilityArchiveGoalBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? It will leave your active Goals list.'**
  String accountabilityArchiveGoalBody(String title);

  /// No description provided for @accountabilityOpenThreadMarkedMissed.
  ///
  /// In en, this message translates to:
  /// **'Open thread marked missed.'**
  String get accountabilityOpenThreadMarkedMissed;

  /// No description provided for @accountabilityOpenThreadArchived.
  ///
  /// In en, this message translates to:
  /// **'Open thread deleted.'**
  String get accountabilityOpenThreadArchived;

  /// No description provided for @accountabilityGoalArchived.
  ///
  /// In en, this message translates to:
  /// **'Goal deleted.'**
  String get accountabilityGoalArchived;

  /// No description provided for @accountabilityGoalUpdated.
  ///
  /// In en, this message translates to:
  /// **'Goal updated.'**
  String get accountabilityGoalUpdated;

  /// No description provided for @accountabilityOpenThreadUpdated.
  ///
  /// In en, this message translates to:
  /// **'Open thread updated.'**
  String get accountabilityOpenThreadUpdated;

  /// No description provided for @accountabilityUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Goals update failed.'**
  String get accountabilityUpdateFailed;

  /// No description provided for @accountabilityStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get accountabilityStatusOpen;

  /// No description provided for @accountabilityStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get accountabilityStatusInProgress;

  /// No description provided for @conversationListEmptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'No chats in {filter}'**
  String conversationListEmptyFilteredTitle(String filter);

  /// No description provided for @conversationListEmptyFilteredMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear the date filter or choose a wider range.'**
  String get conversationListEmptyFilteredMessage;

  /// No description provided for @conversationListNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'No chats matched \"{query}\"{suffix}'**
  String conversationListNoMatchesBody(String query, String suffix);

  /// No description provided for @conversationListNoMatchesSuffixInFilter.
  ///
  /// In en, this message translates to:
  /// **' in {filter}'**
  String conversationListNoMatchesSuffixInFilter(String filter);

  /// No description provided for @conversationDateFilterCustomSingle.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String conversationDateFilterCustomSingle(String date);

  /// No description provided for @conversationDateFilterCustomRange.
  ///
  /// In en, this message translates to:
  /// **'{start} - {end}'**
  String conversationDateFilterCustomRange(String start, String end);

  /// No description provided for @usageSummaryAiCallsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} AI calls'**
  String usageSummaryAiCallsCount(int count);

  /// No description provided for @usageSummaryAiCallsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} AI calls this month'**
  String usageSummaryAiCallsThisMonth(int count);

  /// No description provided for @usageAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage administration'**
  String get usageAdminTitle;

  /// No description provided for @usageAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All users · voice, chat, estimated cost'**
  String get usageAdminSubtitle;

  /// No description provided for @usageAdminOwnerSection.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get usageAdminOwnerSection;

  /// No description provided for @usageAdminPlatformThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Platform this month'**
  String get usageAdminPlatformThisMonth;

  /// No description provided for @usageAdminPlatformAllTime.
  ///
  /// In en, this message translates to:
  /// **'Platform all time'**
  String get usageAdminPlatformAllTime;

  /// No description provided for @usageAdminPlatformYear.
  ///
  /// In en, this message translates to:
  /// **'Platform {year}'**
  String usageAdminPlatformYear(int year);

  /// No description provided for @usageAdminPlatformMonth.
  ///
  /// In en, this message translates to:
  /// **'Platform {monthLabel}'**
  String usageAdminPlatformMonth(String monthLabel);

  /// No description provided for @usageAdminPlatformDay.
  ///
  /// In en, this message translates to:
  /// **'Platform {dayLabel}'**
  String usageAdminPlatformDay(String dayLabel);

  /// No description provided for @usageAdminFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get usageAdminFilterTitle;

  /// No description provided for @usageAdminFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get usageAdminFilterAll;

  /// No description provided for @usageAdminFilterYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get usageAdminFilterYear;

  /// No description provided for @usageAdminFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get usageAdminFilterMonth;

  /// No description provided for @usageAdminFilterDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get usageAdminFilterDay;

  /// No description provided for @usageAdminFilterRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{periodLabel} · {startDate} – {endDate}'**
  String usageAdminFilterRangeLabel(
    String periodLabel,
    String startDate,
    String endDate,
  );

  /// No description provided for @usageAdminAccountsSummary.
  ///
  /// In en, this message translates to:
  /// **'{registeredCount} accounts · {activeCount} with usage · {voiceMinutes} voice · {aiCalls} AI calls'**
  String usageAdminAccountsSummary(
    int registeredCount,
    int activeCount,
    String voiceMinutes,
    int aiCalls,
  );

  /// No description provided for @usageAdminActiveUsersSummary.
  ///
  /// In en, this message translates to:
  /// **'{activeUserCount} active users · {voiceMinutes} voice · {aiCalls} AI calls'**
  String usageAdminActiveUsersSummary(
    int activeUserCount,
    String voiceMinutes,
    int aiCalls,
  );

  /// No description provided for @usageAdminUsersSection.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usageAdminUsersSection;

  /// No description provided for @usageAdminNoRegisteredUsers.
  ///
  /// In en, this message translates to:
  /// **'No registered users yet.'**
  String get usageAdminNoRegisteredUsers;

  /// No description provided for @usageAdminNoUsageInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded in this period.'**
  String get usageAdminNoUsageInPeriod;

  /// No description provided for @usageAdminNoUsageThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No usage recorded this month yet.'**
  String get usageAdminNoUsageThisMonth;

  /// No description provided for @usageAdminUserTileSummary.
  ///
  /// In en, this message translates to:
  /// **'{voiceMinutes} voice · {chatCalls} chat · {voiceCalls} voice calls'**
  String usageAdminUserTileSummary(
    String voiceMinutes,
    int chatCalls,
    int voiceCalls,
  );

  /// No description provided for @usageAdminLoadingUserUsage.
  ///
  /// In en, this message translates to:
  /// **'Loading user usage'**
  String get usageAdminLoadingUserUsage;

  /// No description provided for @usageAdminEstimatedCostThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost this month'**
  String get usageAdminEstimatedCostThisMonth;

  /// No description provided for @usageAdminEstimatedCostPeriod.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost in period'**
  String get usageAdminEstimatedCostPeriod;

  /// No description provided for @usageAdminUsageShape.
  ///
  /// In en, this message translates to:
  /// **'Usage shape'**
  String get usageAdminUsageShape;

  /// No description provided for @usageAdminDailyChartsCaption.
  ///
  /// In en, this message translates to:
  /// **'Daily totals for the loaded date range'**
  String get usageAdminDailyChartsCaption;

  /// No description provided for @usageAdminRadarChartCaption.
  ///
  /// In en, this message translates to:
  /// **'Month-to-date totals (not daily)'**
  String get usageAdminRadarChartCaption;

  /// No description provided for @usageAdminRadarVoiceMin.
  ///
  /// In en, this message translates to:
  /// **'Voice min'**
  String get usageAdminRadarVoiceMin;

  /// No description provided for @usageAdminRadarChatLlm.
  ///
  /// In en, this message translates to:
  /// **'Chat LLM'**
  String get usageAdminRadarChatLlm;

  /// No description provided for @usageAdminRadarVoiceLlm.
  ///
  /// In en, this message translates to:
  /// **'Voice LLM'**
  String get usageAdminRadarVoiceLlm;

  /// No description provided for @usageAdminRadarSttMin.
  ///
  /// In en, this message translates to:
  /// **'STT min'**
  String get usageAdminRadarSttMin;

  /// No description provided for @usageAdminRadarTtsMin.
  ///
  /// In en, this message translates to:
  /// **'TTS min'**
  String get usageAdminRadarTtsMin;

  /// No description provided for @usageCostNotTracked.
  ///
  /// In en, this message translates to:
  /// **'Not tracked'**
  String get usageCostNotTracked;

  /// No description provided for @usageMinutesLessThanOne.
  ///
  /// In en, this message translates to:
  /// **'<1 min'**
  String get usageMinutesLessThanOne;

  /// No description provided for @usageMinutesFormat.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String usageMinutesFormat(int minutes);

  /// No description provided for @usageAdminLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load owner usage right now.'**
  String get usageAdminLoadFailed;

  /// No description provided for @usageAdminUserLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load user usage history.'**
  String get usageAdminUserLoadFailed;

  /// No description provided for @usageSummaryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage right now.'**
  String get usageSummaryLoadFailed;

  /// No description provided for @memoryErrorSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to manage saved information.'**
  String get memoryErrorSignInAgain;

  /// No description provided for @memoryErrorNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'That memory is no longer available.'**
  String get memoryErrorNoLongerAvailable;

  /// No description provided for @memoryErrorEditValidation.
  ///
  /// In en, this message translates to:
  /// **'That memory change could not be saved. Check the fields and try again.'**
  String get memoryErrorEditValidation;

  /// No description provided for @memoryErrorArchiveRefresh.
  ///
  /// In en, this message translates to:
  /// **'That memory could not be deleted. Refresh Memory and try again.'**
  String get memoryErrorArchiveRefresh;

  /// No description provided for @memoryErrorLoadRefresh.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved information. Refresh and try again.'**
  String get memoryErrorLoadRefresh;

  /// No description provided for @memoryErrorLoadConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved information. Check your connection and try again.'**
  String get memoryErrorLoadConnection;

  /// No description provided for @memoryErrorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update this memory. Please try again.'**
  String get memoryErrorUpdateFailed;

  /// No description provided for @memoryErrorArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this memory. Please try again.'**
  String get memoryErrorArchiveFailed;

  /// No description provided for @memoryErrorCreateValidation.
  ///
  /// In en, this message translates to:
  /// **'That memory could not be saved. Check the fields and try again.'**
  String get memoryErrorCreateValidation;

  /// No description provided for @memoryErrorCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this memory. Please try again.'**
  String get memoryErrorCreateFailed;

  /// No description provided for @serviceErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get serviceErrorGeneric;

  /// No description provided for @serviceErrorSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get serviceErrorSignInRequired;

  /// No description provided for @serviceErrorFetchGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not load data right now.'**
  String get serviceErrorFetchGeneric;

  /// No description provided for @serviceErrorCreateGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not save changes right now.'**
  String get serviceErrorCreateGeneric;

  /// No description provided for @serviceErrorUpdateGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not update right now.'**
  String get serviceErrorUpdateGeneric;

  /// No description provided for @serviceErrorDeleteGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not delete right now.'**
  String get serviceErrorDeleteGeneric;

  /// No description provided for @serviceErrorFetchAccounts.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts.'**
  String get serviceErrorFetchAccounts;

  /// No description provided for @serviceErrorCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not create account.'**
  String get serviceErrorCreateAccount;

  /// No description provided for @serviceErrorUpdateAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not update account.'**
  String get serviceErrorUpdateAccount;

  /// No description provided for @serviceErrorDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account.'**
  String get serviceErrorDeleteAccount;

  /// No description provided for @serviceErrorFetchStatementImports.
  ///
  /// In en, this message translates to:
  /// **'Could not load statement imports.'**
  String get serviceErrorFetchStatementImports;

  /// No description provided for @serviceErrorSaveStatementImport.
  ///
  /// In en, this message translates to:
  /// **'Could not save statement import.'**
  String get serviceErrorSaveStatementImport;

  /// No description provided for @serviceErrorDeleteStatementImport.
  ///
  /// In en, this message translates to:
  /// **'Could not delete statement import.'**
  String get serviceErrorDeleteStatementImport;

  /// No description provided for @serviceErrorFetchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions.'**
  String get serviceErrorFetchTransactions;

  /// No description provided for @serviceErrorCreateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Could not create transaction.'**
  String get serviceErrorCreateTransaction;

  /// No description provided for @serviceErrorCreateTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not create transactions.'**
  String get serviceErrorCreateTransactions;

  /// No description provided for @serviceErrorUpdateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Could not update transaction.'**
  String get serviceErrorUpdateTransaction;

  /// No description provided for @serviceErrorUpdateTransactionCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not update transaction categories.'**
  String get serviceErrorUpdateTransactionCategories;

  /// No description provided for @serviceErrorDeleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Could not delete transaction.'**
  String get serviceErrorDeleteTransaction;

  /// No description provided for @serviceErrorDeleteCsvImportTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not delete CSV import transactions.'**
  String get serviceErrorDeleteCsvImportTransactions;

  /// No description provided for @serviceErrorDeleteAccountTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account transactions for that date range.'**
  String get serviceErrorDeleteAccountTransactions;

  /// No description provided for @serviceErrorFetchBudgets.
  ///
  /// In en, this message translates to:
  /// **'Could not load budgets.'**
  String get serviceErrorFetchBudgets;

  /// No description provided for @serviceErrorCreateBudget.
  ///
  /// In en, this message translates to:
  /// **'Could not create budget.'**
  String get serviceErrorCreateBudget;

  /// No description provided for @serviceErrorUpdateBudget.
  ///
  /// In en, this message translates to:
  /// **'Could not update budget.'**
  String get serviceErrorUpdateBudget;

  /// No description provided for @serviceErrorUpdateBudgetCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not update budget categories.'**
  String get serviceErrorUpdateBudgetCategories;

  /// No description provided for @serviceErrorDeleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Could not delete budget.'**
  String get serviceErrorDeleteBudget;

  /// No description provided for @serviceErrorFetchCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories.'**
  String get serviceErrorFetchCategories;

  /// No description provided for @serviceErrorCreateCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not create category.'**
  String get serviceErrorCreateCategory;

  /// No description provided for @serviceErrorUpdateCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not update category.'**
  String get serviceErrorUpdateCategory;

  /// No description provided for @serviceErrorDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not delete category.'**
  String get serviceErrorDeleteCategory;

  /// No description provided for @serviceErrorFetchMerchantCategoryRules.
  ///
  /// In en, this message translates to:
  /// **'Could not load merchant category rules.'**
  String get serviceErrorFetchMerchantCategoryRules;

  /// No description provided for @serviceErrorSaveMerchantCategoryRule.
  ///
  /// In en, this message translates to:
  /// **'Could not save merchant category rule.'**
  String get serviceErrorSaveMerchantCategoryRule;

  /// No description provided for @serviceErrorUpdateMerchantCategoryRules.
  ///
  /// In en, this message translates to:
  /// **'Could not update merchant category rules.'**
  String get serviceErrorUpdateMerchantCategoryRules;

  /// No description provided for @serviceErrorUpdateMerchantCategoryRule.
  ///
  /// In en, this message translates to:
  /// **'Could not update merchant category rule.'**
  String get serviceErrorUpdateMerchantCategoryRule;

  /// No description provided for @serviceErrorDeleteMerchantCategoryRule.
  ///
  /// In en, this message translates to:
  /// **'Could not delete merchant category rule.'**
  String get serviceErrorDeleteMerchantCategoryRule;

  /// No description provided for @serviceErrorRecordAuditEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not record audit event.'**
  String get serviceErrorRecordAuditEvent;

  /// No description provided for @serviceErrorFetchAuditEvents.
  ///
  /// In en, this message translates to:
  /// **'Could not load audit events.'**
  String get serviceErrorFetchAuditEvents;

  /// No description provided for @plaidLinkStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start bank connection.'**
  String get plaidLinkStartFailed;

  /// No description provided for @plaidLinkSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save bank connection.'**
  String get plaidLinkSaveFailed;

  /// No description provided for @plaidLinkParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not parse bank connection.'**
  String get plaidLinkParseFailed;

  /// No description provided for @plaidLinkConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Bank connection is not configured yet.'**
  String get plaidLinkConfigMissing;

  /// No description provided for @plaidLinkCancelled.
  ///
  /// In en, this message translates to:
  /// **'Bank connection was cancelled.'**
  String get plaidLinkCancelled;

  /// No description provided for @plaidLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open bank connection in this browser. Refresh the page and try again.'**
  String get plaidLinkOpenFailed;

  /// No description provided for @plaidLinkGenericFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect this bank right now.'**
  String get plaidLinkGenericFailed;

  /// No description provided for @plaidAccountNoConnectedBank.
  ///
  /// In en, this message translates to:
  /// **'No connected bank to refresh.'**
  String get plaidAccountNoConnectedBank;

  /// No description provided for @plaidAccountParseStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read bank connection status.'**
  String get plaidAccountParseStatusFailed;

  /// No description provided for @plaidAccountGenericFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update this bank connection right now.'**
  String get plaidAccountGenericFailed;

  /// No description provided for @plaidRefreshAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account} other{{count} accounts}}'**
  String plaidRefreshAccountLabel(int count);

  /// No description provided for @plaidRefreshWithTransactionUpdates.
  ///
  /// In en, this message translates to:
  /// **'Accounts refreshed: {accountLabel}, {updateCount, plural, =1{1 transaction update} other{{updateCount} transaction updates}}.'**
  String plaidRefreshWithTransactionUpdates(
    String accountLabel,
    int updateCount,
  );

  /// No description provided for @plaidRefreshBalancesOnlyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Accounts refreshed: {accountLabel}. Balances updated. No new transactions yet — Plaid will sync on its schedule (on-demand transaction pull is not enabled on this Plaid plan).'**
  String plaidRefreshBalancesOnlyUnavailable(String accountLabel);

  /// No description provided for @plaidRefreshBalancesOnly.
  ///
  /// In en, this message translates to:
  /// **'Accounts refreshed: {accountLabel}. Balances updated; no new transactions since last sync.'**
  String plaidRefreshBalancesOnly(String accountLabel);

  /// No description provided for @chatErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Clarity. Check your connection and try again.'**
  String get chatErrorNetwork;

  /// No description provided for @chatErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Try again.'**
  String get chatErrorTimeout;

  /// No description provided for @chatErrorUpload.
  ///
  /// In en, this message translates to:
  /// **'Could not upload that attachment. Try again.'**
  String get chatErrorUpload;

  /// No description provided for @chatErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'That message could not be sent. Check the attachment and try again.'**
  String get chatErrorValidation;

  /// No description provided for @chatErrorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Clarity returned an unexpected response. Try again.'**
  String get chatErrorInvalidResponse;

  /// No description provided for @chatPendingWriteHydrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reload a pending save confirmation. Pull to refresh or reopen this chat.'**
  String get chatPendingWriteHydrationFailed;

  /// No description provided for @chatConfirmWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the save. Tap Retry to try again.'**
  String get chatConfirmWriteFailed;

  /// No description provided for @chatAttachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachment is too large. Maximum size is 2MB.'**
  String get chatAttachmentTooLarge;

  /// No description provided for @chatAttachmentImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large. Maximum size is 5MB.'**
  String get chatAttachmentImageTooLarge;

  /// No description provided for @chatAttachmentPdfTooLarge.
  ///
  /// In en, this message translates to:
  /// **'PDF is too large. Maximum size is 10MB.'**
  String get chatAttachmentPdfTooLarge;

  /// No description provided for @chatAttachmentInvalidType.
  ///
  /// In en, this message translates to:
  /// **'Attach a .txt, .md, .csv, .pdf, .jpg, .png, or .webp file.'**
  String get chatAttachmentInvalidType;

  /// No description provided for @chatAttachmentUtf8Required.
  ///
  /// In en, this message translates to:
  /// **'Attachment must be valid UTF-8 text.'**
  String get chatAttachmentUtf8Required;

  /// No description provided for @chatAttachmentReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected file.'**
  String get chatAttachmentReadFailed;

  /// No description provided for @conversationListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load chats right now.'**
  String get conversationListLoadFailed;

  /// No description provided for @conversationListCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start a new chat right now.'**
  String get conversationListCreateFailed;

  /// No description provided for @conversationListSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not search chats right now.'**
  String get conversationListSearchFailed;

  /// No description provided for @voiceErrorAudioSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the voice call audio session.'**
  String get voiceErrorAudioSessionStartFailed;

  /// No description provided for @voiceErrorPlayRexVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play Rex voice for this reply.'**
  String get voiceErrorPlayRexVoiceFailed;

  /// No description provided for @voiceErrorStreamVoiceAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stream voice audio.'**
  String get voiceErrorStreamVoiceAudioFailed;

  /// No description provided for @voiceErrorCaptureVoiceAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not capture voice audio.'**
  String get voiceErrorCaptureVoiceAudioFailed;

  /// No description provided for @voiceErrorActiveCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Active voice call failed.'**
  String get voiceErrorActiveCallFailed;

  /// No description provided for @voiceErrorNativeSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Native iOS voice session failed.'**
  String get voiceErrorNativeSessionFailed;

  /// No description provided for @voiceErrorAssistantStreamFailed.
  ///
  /// In en, this message translates to:
  /// **'Assistant voice stream failed.'**
  String get voiceErrorAssistantStreamFailed;

  /// No description provided for @voiceErrorAssistantStreamDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Assistant voice stream disconnected. Try voice again.'**
  String get voiceErrorAssistantStreamDisconnected;

  /// No description provided for @voiceErrorOpenAssistantStreamFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Assistant voice stream.'**
  String get voiceErrorOpenAssistantStreamFailed;

  /// No description provided for @voiceErrorStillDidNotHear.
  ///
  /// In en, this message translates to:
  /// **'I still did not hear anything. Tap Try again when you are ready to use voice.'**
  String get voiceErrorStillDidNotHear;

  /// No description provided for @voiceErrorStuckThinkingNative.
  ///
  /// In en, this message translates to:
  /// **'Rex got stuck thinking, so I reset the native voice stream. Try again.'**
  String get voiceErrorStuckThinkingNative;

  /// No description provided for @voiceErrorStuckThinking.
  ///
  /// In en, this message translates to:
  /// **'Rex got stuck thinking, so I reset the voice stream. Try again.'**
  String get voiceErrorStuckThinking;

  /// No description provided for @voiceErrorPreviousResponseInProgress.
  ///
  /// In en, this message translates to:
  /// **'Rex is finishing the previous response. Try again after it finishes.'**
  String get voiceErrorPreviousResponseInProgress;

  /// No description provided for @voiceErrorMicPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is blocked. Enable it in iOS Settings > Privacy & Security > Microphone to call Rex.'**
  String get voiceErrorMicPermanentlyDenied;

  /// No description provided for @voiceErrorMicPermanentlyDeniedWeb.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is blocked for this site. Open your browser site settings, allow the microphone for Clarity, then try again.'**
  String get voiceErrorMicPermanentlyDeniedWeb;

  /// No description provided for @voiceErrorMicRestricted.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is restricted on this device.'**
  String get voiceErrorMicRestricted;

  /// No description provided for @voiceErrorMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to call Rex. Tap Try again to prompt access, or enable it in iOS Settings > Privacy & Security > Microphone.'**
  String get voiceErrorMicDenied;

  /// No description provided for @voiceErrorMicDeniedWeb.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to call Rex. Click Try again and allow microphone access when your browser prompts you.'**
  String get voiceErrorMicDeniedWeb;

  /// No description provided for @voiceErrorMicInsecureContext.
  ///
  /// In en, this message translates to:
  /// **'Voice needs a secure connection. Open Clarity with https:// instead of http://.'**
  String get voiceErrorMicInsecureContext;

  /// No description provided for @voiceErrorMicBrowserSettings.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone for Clarity in your browser site settings (lock icon in the address bar), then tap Try again.'**
  String get voiceErrorMicBrowserSettings;

  /// No description provided for @voiceErrorBackgroundMicRestart.
  ///
  /// In en, this message translates to:
  /// **'Assistant could not restart the microphone in the background. Open Assistant to continue.'**
  String get voiceErrorBackgroundMicRestart;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
