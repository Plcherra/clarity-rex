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
  String get navDashboard => 'Panel';

  @override
  String get navAccounts => 'Cuentas';

  @override
  String get navBudgets => 'Presupuestos';

  @override
  String get navAssistant => 'Asistente';

  @override
  String get navProfile => 'Perfil';

  @override
  String get loadingClarity => 'Cargando Clarity';

  @override
  String get startingClarity => 'Iniciando Clarity';

  @override
  String get authSignInTitle => 'Inicia sesión en Clarity';

  @override
  String get authSignUpTitle => 'Crea tu cuenta';

  @override
  String get authSignInSubtitle => 'Usa tu correo y contraseña para continuar.';

  @override
  String get authSignUpSubtitle =>
      'Usa correo y contraseña para empezar tu espacio financiero.';

  @override
  String get authFullNameLabel => 'Nombre completo';

  @override
  String get authEmailLabel => 'Correo';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authSignInButton => 'Iniciar sesión';

  @override
  String get authCreateAccountButton => 'Crear cuenta';

  @override
  String get authSwitchToSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authSwitchToSignUp => '¿Necesitas cuenta? Crear una';

  @override
  String get authEnterEmailPassword => 'Ingresa tu correo y contraseña.';

  @override
  String get authEnterName => 'Ingresa tu nombre para crear un perfil.';

  @override
  String get authEnterEmailForReset =>
      'Ingresa tu correo para restablecer la contraseña.';

  @override
  String get profileAppearance => 'Apariencia';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String get profileLanguageComingSoon =>
      'Las preferencias de idioma aparecerán aquí.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get importUploadingTransactions => 'Subiendo transacciones...';

  @override
  String chatActionDoneSingle(String action) {
    return 'Listo. Apliqué el cambio de $action.';
  }

  @override
  String chatActionDoneForSubject(String action, String subject) {
    return 'Listo. Apliqué el cambio de $action para $subject.';
  }

  @override
  String chatActionDoneMultiple(String action, int count) {
    return 'Listo. Apliqué el cambio de $action a $count registros.';
  }

  @override
  String chatActionDoneMultipleOne(String action) {
    return 'Listo. Apliqué el cambio de $action a 1 registro.';
  }
}
