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
  String get profileLanguageComingSoon =>
      'Language preferences will appear here.';

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
}
