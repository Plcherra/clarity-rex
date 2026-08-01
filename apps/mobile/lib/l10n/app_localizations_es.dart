// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Claridad';

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
  String get loadingClarity => 'Cargando claridad';

  @override
  String get startingClarity => 'Claridad inicial';

  @override
  String get authSignInTitle => 'Iniciar sesión en Claridad';

  @override
  String get authSignUpTitle => 'Crea tu cuenta';

  @override
  String get authSignInSubtitle =>
      'Utilice su correo electrónico y contraseña para continuar.';

  @override
  String get authSignUpSubtitle =>
      'Utilice el correo electrónico y la contraseña para iniciar su espacio de trabajo de finanzas local.';

  @override
  String get authFullNameLabel => 'nombre completo';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authForgotPassword => '¿Has olvidado tu contraseña?';

  @override
  String get authSignInButton => 'Iniciar sesión';

  @override
  String get authCreateAccountButton => 'Crear una cuenta';

  @override
  String get authSwitchToSignIn => '¿Ya tienes una cuenta? Iniciar sesión';

  @override
  String get authSwitchToSignUp => '¿Necesitas una cuenta? Crea uno';

  @override
  String get authEnterEmailPassword =>
      'Ingrese su correo electrónico y contraseña.';

  @override
  String get authEnterName => 'Ingrese su nombre para crear un perfil.';

  @override
  String get authEnterEmailForReset =>
      'Ingrese su correo electrónico para restablecer su contraseña.';

  @override
  String get authLanguageLabel => 'Idioma';

  @override
  String get authConfirmEmailTitle => 'Confirma tu correo electrónico';

  @override
  String authConfirmEmailSubtitle(String email) {
    return 'Enviamos un enlace de confirmación a $email. Ábrelo en este teléfono — Clarity debería reabrirse y continuar automáticamente.';
  }

  @override
  String get authConfirmEmailHint =>
      'Revisa spam o promociones si no lo ves en unos minutos.';

  @override
  String get authConfirmEmailResendButton => 'Reenviar correo de confirmación';

  @override
  String get authConfirmEmailContinueButton => 'Ya confirmé — continuar';

  @override
  String get authConfirmEmailStillPending =>
      'El correo aún no está confirmado. Abre el enlace de tu bandeja y vuelve aquí.';

  @override
  String authConfirmEmailResent(String email) {
    return 'Se envió de nuevo el correo de confirmación a $email.';
  }

  @override
  String get authConfirmEmailBackToSignIn => 'Volver a iniciar sesión';

  @override
  String get authInfoEmailConfirmedSignIn =>
      'Correo confirmado. Inicia sesión con tu contraseña para continuar.';

  @override
  String get profileAppearance => 'Apariencia';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String profileLanguageUpdated(String language) {
    return 'Idioma establecido en $language.';
  }

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Luz';

  @override
  String get importUploadingTransactions => 'Subiendo transacciones...';

  @override
  String chatActionDoneSingle(String action) {
    return 'Hecho. Apliqué el cambio $action.';
  }

  @override
  String chatActionDoneForSubject(String action, String subject) {
    return 'Hecho. Apliqué el cambio $action para $subject.';
  }

  @override
  String chatActionDoneMultiple(String action, int count) {
    return 'Hecho. Apliqué el cambio $action a los registros $count.';
  }

  @override
  String chatActionDoneMultipleOne(String action) {
    return 'Hecho. Apliqué el cambio $action a 1 registro.';
  }

  @override
  String chatActionMatchedNothing(String action) {
    return 'No coincidió nada, así que el cambio $action no modificó ningún registro.';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Ahorrar';

  @override
  String get commonDelete => 'Borrar';

  @override
  String get commonRetry => 'Rever';

  @override
  String get commonClose => 'Cerca';

  @override
  String get commonArchive => 'Borrar';

  @override
  String get commonMerge => 'Unir';

  @override
  String get commonEnable => 'Permitir';

  @override
  String get commonDisable => 'Desactivar';

  @override
  String get commonOk => 'DE ACUERDO';

  @override
  String get commonKeep => 'Mantener';

  @override
  String get commonDiscard => 'Desechar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonIncome => 'Ingreso';

  @override
  String get commonSpending => 'Gasto';

  @override
  String get commonNet => 'Neto';

  @override
  String get commonUnavailable => 'Indisponible';

  @override
  String get commonSignOut => 'desconectar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonPause => 'Pausar';

  @override
  String get commonImport => 'Importar';

  @override
  String get commonLoading => 'Cargando';

  @override
  String get commonRemove => 'Eliminar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonDismiss => 'Despedir';

  @override
  String get commonKeepEditing => 'Seguir editando';

  @override
  String get personConfirmTitle => 'Guardar persona';

  @override
  String get personConfirmNameLabel => 'Nombre';

  @override
  String get personConfirmRelationshipLabel => 'Relación';

  @override
  String get personConfirmBirthdayLabel => 'Cumpleaños';

  @override
  String get personConfirmNotesLabel => 'Notas';

  @override
  String get personConfirmTwoFieldsRequired =>
      'Agrega al menos 2 campos para guardar.';

  @override
  String get personConfirmDiscardTitle => '¿Descartar esta tarjeta de persona?';

  @override
  String get personConfirmDiscardBody =>
      'Escribiste detalles que aún no se han guardado. ¿Descartarlos?';

  @override
  String get commonToday => 'Hoy';

  @override
  String get commonThisWeek => 'Esta semana';

  @override
  String get commonThisMonth => 'este mes';

  @override
  String get commonAll => 'Todo';

  @override
  String get commonCustom => 'A medida';

  @override
  String get commonActive => 'Activo';

  @override
  String get commonTitle => 'Título';

  @override
  String get commonName => 'Nombre';

  @override
  String get commonDescription => 'Descripción';

  @override
  String get commonStatus => 'Estado';

  @override
  String get commonPriority => 'Prioridad';

  @override
  String get commonImportance => 'Importancia';

  @override
  String get commonSummary => 'Resumen';

  @override
  String get commonNotes => 'Notas';

  @override
  String get commonType => 'Tipo';

  @override
  String get commonLow => 'Bajo';

  @override
  String get commonNormal => 'Normal';

  @override
  String get commonMedium => 'Medio';

  @override
  String get commonHigh => 'Alto';

  @override
  String get commonInfo => 'Info';

  @override
  String get commonCritical => 'Crítico';

  @override
  String get commonNotSet => 'No establecido';

  @override
  String get commonDueDate => 'Fecha de vencimiento';

  @override
  String get commonAccount => 'Cuenta';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get commonExpense => 'Gastos';

  @override
  String get commonTransfer => 'Transferir';

  @override
  String get commonRefund => 'Reembolso';

  @override
  String get commonAdjustment => 'Ajuste';

  @override
  String get commonCreditCardPayment => 'pago con tarjeta de crédito';

  @override
  String get commonChecking => 'De cheques';

  @override
  String get commonSavings => 'Ahorros';

  @override
  String get commonCard => 'Tarjeta';

  @override
  String get commonBuiltIn => 'Incorporado';

  @override
  String get commonHidden => 'Oculto';

  @override
  String get commonVisible => 'Visible';

  @override
  String get commonDisabled => 'Desactivado';

  @override
  String get commonCategories => 'Categorías';

  @override
  String get commonRules => 'Normas';

  @override
  String get commonHistory => 'Historia';

  @override
  String get commonPeople => 'Gente';

  @override
  String get commonPreferences => 'Preferencias';

  @override
  String get commonPerson => 'Persona';

  @override
  String get commonPlan => 'Plan';

  @override
  String get commonRule => 'Regla';

  @override
  String get commonMemory => 'Memoria';

  @override
  String get commonConversation => 'Conversación';

  @override
  String get commonUndated => 'Sin fecha';

  @override
  String get commonYesterday => 'Ayer';

  @override
  String get commonOlder => 'Más viejo';

  @override
  String get commonUpcoming => 'Próximo';

  @override
  String get commonInactive => 'Inactivo';

  @override
  String get commonAttachment => 'Adjunto';

  @override
  String get commonStart => 'Comenzar';

  @override
  String get commonEnd => 'Fin';

  @override
  String get commonLeft => 'Izquierda';

  @override
  String get commonOver => 'Encima';

  @override
  String get commonSpent => 'Gastado';

  @override
  String get commonBudgeted => 'Presupuestado';

  @override
  String get commonMonthly => 'Mensual';

  @override
  String get commonWeekly => 'Semanal';

  @override
  String commonOnTrack(int onTrack, int budgeted) {
    return '$onTrack/$budgeted en camino';
  }

  @override
  String commonTransactionCount(int count) {
    return '$count transacciones';
  }

  @override
  String get commonTransactionCountOne => '1 transacción';

  @override
  String commonRecordsApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registros',
      one: '1 registro',
    );
    return 'Aplicado a $_temp0.';
  }

  @override
  String commonAiCalls(int count) {
    return '$count llamadas de IA';
  }

  @override
  String commonAiCallsThisMonth(int count) {
    return '$count Llamadas de IA este mes';
  }

  @override
  String commonMinutesFormat(String minutes) {
    return '$minutes min';
  }

  @override
  String get commonMinutesUnderOne => '<1 minuto';

  @override
  String commonAddedDate(String date) {
    return 'Añadido $date';
  }

  @override
  String commonUpdatedDate(String date) {
    return 'Actualizado $date';
  }

  @override
  String commonDueDateValue(String date) {
    return 'Vencimiento $date';
  }

  @override
  String commonTargetDateValue(String date) {
    return 'Objetivo $date';
  }

  @override
  String commonLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String commonAcrossAccounts(int accountCount, String accountCountSuffix) {
    return 'En $accountCount cuenta conectada $accountCountSuffix';
  }

  @override
  String commonConnectedAccountCount(int count, String countSuffix) {
    return '$count cuenta conectada$countSuffix';
  }

  @override
  String commonCopiedLabel(String label) {
    return '$label copiado.';
  }

  @override
  String commonArchivedNamed(String label) {
    return '$label borrado';
  }

  @override
  String get commonCommaSeparated => 'Separados por comas';

  @override
  String get commonAmountHintDash => '—';

  @override
  String commonMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get commonMonthJanuary => 'Enero';

  @override
  String get commonMonthFebruary => 'Febrero';

  @override
  String get commonMonthMarch => 'Marzo';

  @override
  String get commonMonthApril => 'Abril';

  @override
  String get commonMonthMay => 'Puede';

  @override
  String get commonMonthJune => 'Junio';

  @override
  String get commonMonthJuly => 'Julio';

  @override
  String get commonMonthAugust => 'Agosto';

  @override
  String get commonMonthSeptember => 'Septiembre';

  @override
  String get commonMonthOctober => 'Octubre';

  @override
  String get commonMonthNovember => 'Noviembre';

  @override
  String get commonMonthDecember => 'Diciembre';

  @override
  String get commonMonthShortJan => 'Ene';

  @override
  String get commonMonthShortFeb => 'Feb';

  @override
  String get commonMonthShortMar => 'Mar';

  @override
  String get commonMonthShortApr => 'Abr';

  @override
  String get commonMonthShortMay => 'Puede';

  @override
  String get commonMonthShortJun => 'Jun';

  @override
  String get commonMonthShortJul => 'Jul';

  @override
  String get commonMonthShortAug => 'Ago';

  @override
  String get commonMonthShortSep => 'Sep';

  @override
  String get commonMonthShortOct => 'Oct';

  @override
  String get commonMonthShortNov => 'Nov';

  @override
  String get commonMonthShortDec => 'Dic';

  @override
  String get commonMonthShortOld => 'Viejo';

  @override
  String get bootErrorTitle => 'La claridad no pudo comenzar.';

  @override
  String get bootErrorTryAgain => 'Intentar otra vez';

  @override
  String get bootErrorFallbackMessage =>
      'Comprueba tu conexión y vuelve a intentarlo.';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a Claridad';

  @override
  String get onboardingSubtitle =>
      'Nombra tu espacio de Clarity. A continuación, puede conectar su banco o utilizar CSV como respaldo manual.';

  @override
  String get onboardingNameLabel => 'Su nombre';

  @override
  String get onboardingNameHint => 'pedro';

  @override
  String get profileScreenTitle => 'Perfil';

  @override
  String get profileEditNameTitle => 'Editar nombre de perfil';

  @override
  String get profileUpdatedSnackBar => 'Perfil actualizado.';

  @override
  String get profileUpdateFailed => 'No se pudo actualizar el perfil.';

  @override
  String get profileSignOutTitle => '¿Desconectar?';

  @override
  String get profileSignOutBody =>
      'Puedes volver a iniciar sesión cuando estés listo.';

  @override
  String get profileDefaultUserName => 'Usuario de claridad';

  @override
  String get profileAccountSection => 'Cuenta';

  @override
  String get profileNameTitle => 'Nombre del perfil';

  @override
  String get profileAddYourName => 'Añade tu nombre';

  @override
  String get profileEmailTitle => 'Correo';

  @override
  String get profileEmailUnknown => 'Esta cuenta no tiene correo';

  @override
  String get profileEmailChangeAction => 'Cambiar correo';

  @override
  String get profileEmailChangeBody =>
      'Clarity envía un enlace de confirmación. Tu correo solo cambia cuando lo abres.';

  @override
  String get profileEmailNewLabel => 'Correo nuevo';

  @override
  String get profileEmailChangeSent =>
      'Confirmación enviada. Tu correo cambia cuando abras el enlace.';

  @override
  String get profileEmailChangeFailed =>
      'No se pudo iniciar el cambio de correo.';

  @override
  String get profileEmailInvalid => 'Eso no parece una dirección de correo.';

  @override
  String get profileEmailSame => 'Ese ya es tu correo.';

  @override
  String get profileChangePhoto => 'Cambiar foto';

  @override
  String get profileTakePhoto => 'Tomar una foto';

  @override
  String get profileChoosePhoto => 'Elegir una foto';

  @override
  String get profileRemovePhoto => 'Quitar foto';

  @override
  String get profilePhotoUpdated => 'Foto actualizada';

  @override
  String get profilePhotoRemoved => 'Foto eliminada';

  @override
  String get profilePhotoUnsupported =>
      'Clarity acepta imágenes JPEG, PNG o WebP.';

  @override
  String get profilePhotoTooLarge =>
      'Esa foto es muy grande. Prueba con una de menos de 2 MB.';

  @override
  String get profilePhotoFailed => 'No se pudo actualizar tu foto.';

  @override
  String get profileMfaTitle => 'Autenticación multifactor';

  @override
  String get profileMfaSubtitle =>
      'Opciones de seguridad y configuración de la aplicación de autenticación';

  @override
  String get profileRexVoiceSection => 'rex y voz';

  @override
  String get profileVoiceUsageTitle => 'Uso de voz';

  @override
  String get profileVoiceUsageSubtitle =>
      'Minutos de hoy, esta semana y este mes en web y móvil';

  @override
  String get profileSessionSection => 'Sesión';

  @override
  String get profileSignOutSubtitle =>
      'Dejar este dispositivo fuera de Clarity';

  @override
  String get profileDeleteAccountTitle => '¿Eliminar cuenta?';

  @override
  String get profileDeleteAccountBody =>
      'Esto elimina permanentemente tu cuenta de Clarity y los datos guardados. Se quitarán las conexiones bancarias. No se puede deshacer.';

  @override
  String get profileDeleteAccountConfirm => 'Eliminar cuenta';

  @override
  String get profileDeleteAccountSubtitle =>
      'Eliminar permanentemente tu cuenta y datos de Clarity';

  @override
  String get profileDeleteAccountFailed =>
      'No se pudo eliminar tu cuenta. Inténtalo de nuevo o contacta con soporte.';

  @override
  String get profileHeaderLabel => 'Perfil de claridad';

  @override
  String get usageSummaryTitle => 'Uso de voz';

  @override
  String get usageSummaryLoading => 'Cargando uso';

  @override
  String get usageSummaryDailyVoiceMinutes => 'Minutos de voz diarios';

  @override
  String get usageSummaryDailyAiCalls => 'Llamadas diarias de IA';

  @override
  String get usageSummaryHeaderLabel => 'Actividad de voz de Rex';

  @override
  String homeShellBankConnectedSuccess(
    String institutionName,
    String accountsSyncedSuffix,
  ) {
    return 'Banco conectado exitosamente: $institutionName$accountsSyncedSuffix.';
  }

  @override
  String get homeShellBankConnectedYourBank => 'tu banco';

  @override
  String homeShellBankConnectedAccountsSynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return ' y sincronizó $_temp0';
  }

  @override
  String homeShellBankConnectionStoppedWithCode(String errorCode) {
    return 'La conexión bancaria se detuvo antes de finalizar. Puedes intentarlo de nuevo. ($errorCode)';
  }

  @override
  String homeShellBankConnectionStoppedWithStatus(String status) {
    return 'La conexión bancaria se detuvo antes de finalizar. Estado del cuadro: $status.';
  }

  @override
  String get homeShellBankConnectionCancelled =>
      'Conexión bancaria cancelada. No se agregó ninguna cuenta.';

  @override
  String get homeShellBankConnectionOpenFailed =>
      'No se pudo abrir la conexión bancaria.';

  @override
  String get dashboardOverviewTitle => 'Descripción general';

  @override
  String get dashboardOverviewImportCsvTooltip => 'Importar CSV en su lugar';

  @override
  String get dashboardOverviewDeleteCsvUploadTooltip => 'Eliminar carga CSV';

  @override
  String get dashboardOverviewDeleteAccountTooltip => 'Eliminar cuenta';

  @override
  String get dashboardOverviewMonthlyCashFlow => 'flujo de caja mensual';

  @override
  String get dashboardOverviewSpendingByCategory => 'Gasto por categoría';

  @override
  String get dashboardOverviewIncomeVsSpending => 'Ingresos versus gastos';

  @override
  String get dashboardOverviewSixMonthTrend => 'Tendencia de gasto';

  @override
  String get financeChartRangeLabel => 'Rango del gráfico';

  @override
  String get financeChartRange3Months => '3M';

  @override
  String get financeChartRange6Months => '6M';

  @override
  String get financeChartRange12Months => '1A';

  @override
  String get dashboardOverviewSpendingPressure => 'Presión de gasto';

  @override
  String get dashboardOverviewBudgetPerformance => 'Desempeño del presupuesto';

  @override
  String get dashboardOverviewAccountHealth => 'Estado de la cuenta';

  @override
  String get dashboardOverviewDataLoadBannerTitle =>
      'Algunos datos financieros no se pudieron cargar.';

  @override
  String dashboardOverviewDataLoadBannerBody(String sourceLabel) {
    return 'Claridad muestra los registros disponibles, pero $sourceLabel puede estar incompleto. Rex tratará las respuestas financieras como degradadas hasta que se actualice.';
  }

  @override
  String get dashboardOverviewDataLoadBannerFallbackSource =>
      'datos financieros';

  @override
  String get dashboardOverviewLoadingLabel =>
      'Cargando tus datos financieros...';

  @override
  String get dashboardEmptyConnectFirstBankTitle => 'Conecta tu primer banco';

  @override
  String get dashboardEmptyConnectFirstBankBody =>
      'Clarity funciona mejor con cuentas conectadas, por lo que los saldos y las transacciones se mantienen actualizados automáticamente.';

  @override
  String get dashboardResolvingTitle => 'Resolver transacciones importadas';

  @override
  String get dashboardResolvingBody =>
      'Su extracto está conectado, pero las filas de transacciones aún se están cargando. Los valores aparecerán cuando se complete la lectura del modelo.';

  @override
  String get dashboardOverviewTotalBalance => 'saldo total';

  @override
  String get dashboardOverviewAccountBalance => 'Saldo de cuenta';

  @override
  String get dashboardOverviewFromConnectedAccounts =>
      'Desde tus cuentas conectadas';

  @override
  String get dashboardOverviewThisMonthLabel => 'este mes';

  @override
  String get dashboardOverviewActivityNotBalanceNote =>
      'Actividad este mes: no es lo mismo que el saldo';

  @override
  String get dashboardOverviewSavings => 'Ahorros';

  @override
  String dashboardOverviewSavingsMovedIn(String amount) {
    return '$amount ingresados';
  }

  @override
  String dashboardOverviewSavingsTakenOut(String amount) {
    return '$amount retirados';
  }

  @override
  String get dashboardOverviewSavingsUnchanged => 'Sin movimientos este mes';

  @override
  String get dashboardInsightsStripTitle => 'Qué vigilar';

  @override
  String dashboardInsightsNetNegative(String amount) {
    return 'Los gastos superan los ingresos por $amount este mes.';
  }

  @override
  String dashboardInsightsNetPositive(String amount) {
    return 'El flujo neto va $amount adelante este mes.';
  }

  @override
  String get dashboardInsightsNetBalanced =>
      'Ingresos y gastos están equilibrados este mes.';

  @override
  String dashboardInsightsMomLeakUp(
    String category,
    String percent,
    String amount,
  ) {
    return '$category subió $percent mes a mes ($amount).';
  }

  @override
  String dashboardInsightsMomLeakNew(String category, String amount) {
    return '$category es nueva presión de gasto con $amount este mes.';
  }

  @override
  String dashboardInsightsBudgetOver(String category, String amount) {
    return '$category supera el presupuesto por $amount.';
  }

  @override
  String get dashboardInsightsSeeChart => 'Ver gráfico';

  @override
  String get insightsSeeAll => 'Ver todo';

  @override
  String get insightsFeedTitle => 'Insights';

  @override
  String get insightsOpenTooltip => 'Insights';

  @override
  String get insightsCurrentSection => 'Qué necesita atención';

  @override
  String get insightsSavedSection => 'Alertas guardadas';

  @override
  String get insightsFeedEmpty =>
      'No hay señales actuales por ahora. Vuelve después de nuevo gasto o actividad de presupuesto.';

  @override
  String get insightsSavedEmpty =>
      'Aún no hay alertas guardadas. Activa los insights proactivos en Perfil para conservarlos con el tiempo.';

  @override
  String get insightsReviewDashboard => 'Revisar en el Panel';

  @override
  String get insightsTypeSpendingPressure => 'Presión de gasto';

  @override
  String get insightsTypeBudgetOver => 'Sobre presupuesto';

  @override
  String get insightsTypeCashFlow => 'Flujo de efectivo';

  @override
  String get insightsTypeAccountability => 'Metas y hábitos';

  @override
  String get insightsGuidanceSpendingPressure =>
      'Esta categoría está impulsando un gasto inusual. Revisa transacciones recientes y decide si recortar o fijar un presupuesto más claro.';

  @override
  String get insightsGuidanceBudgetOver =>
      'Este presupuesto ya se excedió. Ajusta el límite si el gasto es intencional, o pausa compras relacionadas hasta que se reinicie el periodo.';

  @override
  String get insightsGuidanceCashFlow =>
      'El flujo neto necesita atención este mes. Compara ingresos y gastos antes de nuevos compromisos.';

  @override
  String get insightsGuidanceAccountability =>
      'Una meta o hilo abierto necesita un check-in. Abre Metas para actualizar el progreso o ajustar el plan.';

  @override
  String get insightsSourceDashboard => 'Desde tu panel';

  @override
  String get insightsSourceAccountability => 'Desde metas y accountability';

  @override
  String get insightsStorageUnavailable =>
      'El almacenamiento de insights guardados aún no está disponible. Las señales en vivo arriba siguen funcionando con los datos de tu panel.';

  @override
  String get insightsApiUnreadableError =>
      'El backend devolvió un error ilegible.';

  @override
  String get insightsApiGenericError => 'La API de Clarity devolvió un error.';

  @override
  String get insightsApiInvalidListResponse =>
      'Respuesta de lista de insights no válida.';

  @override
  String get insightsApiInvalidListPayload =>
      'Carga de lista de insights no válida.';

  @override
  String get insightsApiInvalidSyncResponse =>
      'Respuesta de sincronización de insights no válida.';

  @override
  String get insightsApiInvalidMarkReadResponse =>
      'Respuesta de marcar como leído no válida.';

  @override
  String get companionScreenTitle => 'Compañero';

  @override
  String get assistantCompanionSettingsTitle => 'Guardado del compañero';

  @override
  String get assistantCompanionSettingsSubtitle =>
      'Elige cómo Rex sugiere metas, hilos abiertos y memoria en el chat. Off = solo chat. Texto = di sí en el chat. Tarjeta = tarjeta de confirmación.';

  @override
  String get assistantCompanionSettingsGearLabel => 'Ajustes del compañero';

  @override
  String get assistantCompanionSettingsTabLabel => 'Guardados';

  @override
  String get assistantAutoProposalsModeLabel => 'Sugerencias automáticas';

  @override
  String get assistantAutoProposalsModeOff => 'Desactivado';

  @override
  String get assistantAutoProposalsModeText => 'Solo texto';

  @override
  String get assistantAutoProposalsModeCard => 'Tarjeta de confirmación';

  @override
  String get assistantAutoProposalsModeOffHint =>
      'Rex nunca propone guardados por su cuenta. Igual hace lo que le pidas.';

  @override
  String get assistantAutoProposalsModeTextHint =>
      'Rex pregunta en el chat (di sí para guardar). Sin tarjeta de confirmación.';

  @override
  String get assistantAutoProposalsModeCardHint =>
      'Rex muestra una tarjeta editable antes de guardar.';

  @override
  String get assistantAutoProposalsTypeThreads =>
      'Hilos abiertos (hábitos y seguimiento)';

  @override
  String get assistantAutoProposalsTypeGoals => 'Metas (logros)';

  @override
  String get assistantAutoProposalsTypeMemory =>
      'Memoria (hechos y preferencias)';

  @override
  String get chatShowMore => 'Ver más';

  @override
  String get chatShowLess => 'Ver menos';

  @override
  String get dashboardChartCategorySpendSubtitle =>
      'Total de este mes · toca una categoría';

  @override
  String get dashboardChartSpendingPressureSubtitle =>
      'Presión mes a mes · toca una categoría';

  @override
  String dashboardChartCategoryDrilldownHint(String category) {
    return 'Ver transacciones de $category';
  }

  @override
  String get categoryDetailLoading => 'Cargando categoría…';

  @override
  String get categoryDetailSpentThisMonth => 'GASTADO ESTE MES';

  @override
  String get categoryDetailNoTransactions =>
      'No hay transacciones en esta categoría este mes.';

  @override
  String get categoryDetailWhereItWent => 'A dónde fue';

  @override
  String get categoryDetailTapMerchantHint =>
      'Toca un lugar para ver sus transacciones';

  @override
  String get categoryDetailNewThisMonth =>
      'Nueva este mes: no hubo nada el mes pasado';

  @override
  String get categoryDetailNoLastMonthSpending =>
      'Nada en esta categoría el mes pasado';

  @override
  String categoryDetailUpFromLastMonth(String change) {
    return '$change más que el mes pasado';
  }

  @override
  String categoryDetailDownFromLastMonth(String change) {
    return '$change menos que el mes pasado';
  }

  @override
  String categoryDetailShareOfSpending(String percent) {
    return '$percent de todo lo que gastaste este mes';
  }

  @override
  String categoryDetailAverageTransaction(String amount) {
    return '$amount por transacción en promedio';
  }

  @override
  String categoryDetailOverBudget(String amount, String budget) {
    return '$amount por encima del presupuesto de $budget';
  }

  @override
  String categoryDetailWithinBudget(String amount, String budget) {
    return 'Quedan $amount del presupuesto de $budget';
  }

  @override
  String get dashboardSectionCoreCharts => 'Gráficos principales';

  @override
  String get dashboardSectionTrendCharts => 'Tendencias';

  @override
  String get dashboardSectionTrendChartsHint =>
      'Mezcla de ingresos e historial de gastos';

  @override
  String get dashboardSectionSpendingAnalysis => 'Análisis de gastos';

  @override
  String get dashboardSectionSpendingAnalysisHint =>
      'Categorías que suben vs el mes pasado';

  @override
  String get dashboardTransactionsSectionTitle => 'Actas';

  @override
  String get transactionsMiniAnalyticsTitle => 'Este mes de un vistazo';

  @override
  String get transactionsMiniAnalyticsSubtitle =>
      'Mismos totales que el Panel para el mes actual';

  @override
  String get transactionsMiniAnalyticsSpent => 'Gastado';

  @override
  String get transactionsMiniAnalyticsIncome => 'Ingresos';

  @override
  String get transactionsMiniAnalyticsNet => 'Neto';

  @override
  String get transactionsMiniAnalyticsTrend =>
      'Tendencia de gasto a seis meses';

  @override
  String get transactionsMiniAnalyticsTopCategories => 'Principales categorías';

  @override
  String get dashboardTransactionsClearFilters => 'Claro';

  @override
  String get dashboardTransactionsLoadingLabel => 'Cargando transacciones';

  @override
  String get dashboardTransactionsLoadError =>
      'No se pudieron cargar transacciones.';

  @override
  String get dashboardTransactionsNoImportedHistory => 'Sin historia importada';

  @override
  String get dashboardTransactionsModeMonths => 'Meses';

  @override
  String get dashboardTransactionsModeCategories => 'Categorías';

  @override
  String get dashboardTransactionsSearchHint =>
      'Buscar comerciante, categoría, mes o monto';

  @override
  String get dashboardTransactionsFilterCategory => 'Categoría';

  @override
  String get dashboardTransactionsFilterAllCategories => 'Todas las categorias';

  @override
  String get dashboardTransactionsFilterAccount => 'Cuenta';

  @override
  String get dashboardTransactionsFilterAllAccounts => 'Todas las cuentas';

  @override
  String get dashboardTransactionsFilterRole => 'Role';

  @override
  String get dashboardTransactionsFilterAllRoles => 'Todos los roles';

  @override
  String get dashboardTransactionsTimeFilterAllHistory => 'toda la historia';

  @override
  String get dashboardTransactionsTimeFilterDashboardMonth => 'Mes del panel';

  @override
  String get dashboardTransactionsTimeFilterLatestTxMonth => 'Último mes de tx';

  @override
  String get dashboardTransactionsTimeFilterLatestTxYear => 'último año de tx';

  @override
  String get dashboardTransactionsSortNewest => 'El más nuevo';

  @override
  String get dashboardTransactionsSortOldest => 'más antiguo';

  @override
  String get dashboardTransactionsSortLargest => 'más grande';

  @override
  String get dashboardTransactionsSortMerchant => 'Comerciante A-Z';

  @override
  String get dashboardTransactionsNoCategoriesMatch =>
      'Ninguna categoría coincide.';

  @override
  String get dashboardTransactionsNoMonthsAfterFilter =>
      'No se muestran meses después de filtrar este archivo.';

  @override
  String get dashboardTransactionsNetLabel => 'neto';

  @override
  String dashboardTransactionsHistoryRange(String dateRange) {
    return 'Historia: $dateRange';
  }

  @override
  String dashboardTransactionsDashboardMonthRange(String dateRange) {
    return 'Mes del panel: $dateRange';
  }

  @override
  String dashboardTransactionsLatestTxMonthRange(String dateRange) {
    return 'Último mes de transacción: $dateRange';
  }

  @override
  String dashboardTransactionsLatestTxYearRange(String dateRange) {
    return 'Año de la última transacción: $dateRange';
  }

  @override
  String dashboardTransactionsTapMonthHint(String dateRangeDescription) {
    return 'Toque un mes para inspeccionar las transacciones | $dateRangeDescription';
  }

  @override
  String dashboardTransactionsFilteredCount(
    int filtered,
    int total,
    String dateRangeDescription,
  ) {
    return '$filtered de $total transacciones | $dateRangeDescription';
  }

  @override
  String get accountsScreenRefreshTooltip => 'Actualizar cuentas';

  @override
  String get accountsScreenAddAccountTooltip => 'Agregar cuenta';

  @override
  String get accountsScreenLoadError => 'No se pudieron cargar cuentas.';

  @override
  String get accountsScreenLoadingLabel => 'Cargando cuentas';

  @override
  String get accountsSummaryTotalBalance => 'saldo total';

  @override
  String get accountsEmptyTitle => 'Conecta tus cuentas';

  @override
  String get accountsEmptyBody =>
      'Comience con cuentas bancarias conectadas para que Clarity pueda mantener los saldos y las transacciones actualizados.';

  @override
  String get connectBankCardConnectButton => 'Conectar banco';

  @override
  String get connectBankCardImportCsvButton => 'Importar CSV en su lugar';

  @override
  String get connectBankCardAddManualButton => 'Agregar cuenta manual';

  @override
  String get csvImportMobileOnlyMessage =>
      'La importación CSV está disponible en la app móvil por ahora.';

  @override
  String get plaidConnectWebUnavailableMessage =>
      'La conexión bancaria no está disponible en este dispositivo. Usa la app de iOS o Android para vincular cuentas.';

  @override
  String get accountsNoticeDismissTooltip => 'Despedir';

  @override
  String accountTileThisMonthNet(String amount) {
    return 'Este mes $amount neto';
  }

  @override
  String get accountTileViewAccount => 'Ver cuenta';

  @override
  String get plaidAccountAvailableLabel => 'Disponible';

  @override
  String get plaidAccountThisMonthLabel => 'este mes';

  @override
  String plaidAccountInOutSummary(String income, String spending) {
    return '$income entrada / $spending salida';
  }

  @override
  String get plaidAccountLastSyncedUnavailable =>
      'Última sincronización no disponible';

  @override
  String get plaidAccountLastSyncedJustNow =>
      'Última sincronización hace un momento';

  @override
  String plaidAccountLastSyncedMinutesAgo(int minutes) {
    return 'Última sincronización hace ${minutes}m';
  }

  @override
  String plaidAccountLastSyncedHoursAgo(int hours) {
    return 'Última sincronización hace ${hours}h';
  }

  @override
  String plaidAccountLastSyncedDate(String date) {
    return 'Última sincronización $date';
  }

  @override
  String get plaidAccountResyncTooltipSyncing => 'Sincronización';

  @override
  String get plaidAccountResyncTooltipLoginRequired =>
      'Iniciar sesión requerido';

  @override
  String get plaidAccountResyncTooltipExpiringSoon => 'Expira pronto';

  @override
  String get plaidAccountResyncTooltipDisconnected => 'Desconectado';

  @override
  String get plaidAccountResyncTooltipDefault => 'resincronizar';

  @override
  String get plaidAccountDisconnectTooltip => 'Desconectar banco';

  @override
  String get addAccountDialogTitle => 'Nueva cuenta';

  @override
  String get addAccountDialogInstitutionLabel => 'Institución (opcional)';

  @override
  String get addAccountDialogTypeLabel => 'Tipo';

  @override
  String get addAccountDialogBalanceLabel => 'Saldo actual (opcional)';

  @override
  String get addAccountDialogInvalidBalance =>
      'Ingrese un saldo válido o déjelo en blanco.';

  @override
  String get accountsSheetAddAccountTitle => 'Agregar cuenta';

  @override
  String get accountsSheetAddAccountSubtitle =>
      'Conecte otro banco con Plaid o utilice herramientas manuales cuando necesite un respaldo.';

  @override
  String get accountsSheetConnectBankTitle => 'Conectar banco';

  @override
  String get accountsSheetConnectBankSubtitle =>
      'Utilice Plaid para agregar otro banco.';

  @override
  String get accountsSheetImportCsvTitle => 'Importar CSV en su lugar';

  @override
  String get accountsSheetImportCsvSubtitle =>
      'Cree una cuenta manual para archivos bancarios.';

  @override
  String get accountsSheetAddManualTitle => 'Agregar cuenta manual';

  @override
  String get accountsSheetAddManualSubtitle =>
      'Seguimiento de una cuenta sin cuadros.';

  @override
  String get accountsScreenDisconnectTitle => '¿Desconectar el banco?';

  @override
  String accountsScreenDisconnectContent(String accountName) {
    return '¿Desconectar $accountName? Esto detiene la futura sincronización de Plaid para este banco. La historia existente permanece en Claridad.';
  }

  @override
  String get accountsScreenDisconnectButton => 'Desconectar banco';

  @override
  String get accountsScreenBankDisconnectedSnack => 'Banco desconectado.';

  @override
  String get accountsNavigationCouldNotSaveAccount =>
      'No se pudo guardar la cuenta.';

  @override
  String get csvPlaidWarningTitle => '¿Importar CSV a la cuenta conectada?';

  @override
  String csvPlaidWarningContent(String accountName) {
    return '$accountName ya se sincroniza a través de Plaid. Importar un CSV aquí puede agregar filas duplicadas si el archivo se superpone con transacciones sincronizadas.';
  }

  @override
  String get csvPlaidWarningContinue => 'Continuar importando';

  @override
  String get accountSelectionAppBarTitle => 'Importar CSV en su lugar';

  @override
  String get accountSelectionPreviewingCsv => 'Vista previa CSV...';

  @override
  String get accountSelectionCouldNotImport =>
      'No se pudo importar este archivo.';

  @override
  String get accountSelectionEmptyTitle =>
      'Agregar una cuenta manual para este CSV';

  @override
  String get accountSelectionAddManualButton => 'Agregar cuenta manual';

  @override
  String get accountSelectionInstructions =>
      'La importación CSV es manual. Elija la cuenta a la que pertenece este archivo; Las cuentas bancarias conectadas se actualizan automáticamente.';

  @override
  String get accountSelectionCsvMayDuplicate =>
      'CSV puede duplicar filas sincronizadas';

  @override
  String get csvPreviewDialogTitle => 'Vista previa de importación CSV';

  @override
  String get csvPreviewDialogDateRange => 'Rango de fechas';

  @override
  String get csvPreviewDialogRowsFound => 'Filas encontradas';

  @override
  String get csvPreviewDialogNewRows => 'Nuevas filas';

  @override
  String get csvPreviewDialogDuplicates => 'Duplicados';

  @override
  String get csvPreviewDialogSpendingRows => 'Filas de gasto';

  @override
  String get csvPreviewDialogIncomeRows => 'Filas de ingresos';

  @override
  String get csvPreviewDialogEndingBalance => 'Saldo final';

  @override
  String get csvPreviewDialogNoNewRows => 'No hay filas nuevas';

  @override
  String get accountDetailFallbackTitle => 'Cuenta';

  @override
  String get accountDetailLoadingLabel => 'Cargando cuenta';

  @override
  String get accountDetailLoadError => 'No se pudo cargar la cuenta.';

  @override
  String get accountDetailDeletingCsvProgress => 'Eliminando carga CSV...';

  @override
  String get accountDetailDeleteCsvUploadTitle => 'Eliminar carga CSV';

  @override
  String get accountDetailConfirmDeleteCsvTitle => '¿Eliminar esta carga CSV?';

  @override
  String get accountDetailDeleteUploadButton => 'Eliminar carga';

  @override
  String get accountDetailDeleteAccountTitle => '¿Eliminar cuenta?';

  @override
  String get accountDetailDeleteAccountContent =>
      '¿Eliminar esta cuenta y todas sus transacciones? Esto no se puede deshacer.';

  @override
  String get accountDetailDeleteAccountButton => 'Eliminar cuenta';

  @override
  String get accountDetailKeepCategories => 'Mantener';

  @override
  String get accountDetailDeleteCategories => 'Borrar';

  @override
  String get chatPageDefaultTitle => 'Rex';

  @override
  String get chatPageSendingImage => 'Enviando imagen…';

  @override
  String get chatPageSendFailed => 'No se pudo enviar el mensaje.';

  @override
  String get chatPageReadFileFailed =>
      'No se pudo leer el archivo seleccionado.';

  @override
  String get chatPageStartVoiceFailed => 'No se pudo iniciar Rex.';

  @override
  String get chatPageShowVoiceCallTooltip => 'Mostrar llamada de voz';

  @override
  String get chatPageCallRexTooltip => 'llamar a rex';

  @override
  String get chatInputAttachTooltip => 'Adjuntar archivo o imagen';

  @override
  String get chatInputAttachWebTooltip => 'Adjuntar un archivo';

  @override
  String get chatInputStartVoiceModeTooltip => 'Iniciar modo de voz';

  @override
  String get chatInputVoiceWebTooltip =>
      'Iniciar voz en el navegador (mantén esta pestaña abierta)';

  @override
  String get voiceWebUnavailableMessage =>
      'La voz no está disponible aquí. Usa el chat, o abre Clarity en iOS o Android.';

  @override
  String get voiceWebForegroundOnlyHint =>
      'Voz en el navegador — mantén esta pestaña abierta';

  @override
  String get chatInputMessageHint => 'Asistente de mensajes…';

  @override
  String get chatInputSendTooltip => 'Enviar';

  @override
  String get chatInputRemoveAttachmentTooltip => 'Quitar archivo adjunto';

  @override
  String get attachmentSheetTitle => 'Adjuntar';

  @override
  String get attachmentSheetGalleryTitle => 'Galería';

  @override
  String get attachmentSheetGallerySubtitle => 'Elija una imagen de las fotos.';

  @override
  String get attachmentSheetCameraTitle => 'Cámara';

  @override
  String get attachmentSheetCameraSubtitle => 'Toma una nueva foto.';

  @override
  String get attachmentSheetFilesTitle => 'Archivos';

  @override
  String get attachmentSheetFilesSubtitle =>
      'Elija archivos PDF, de texto, CSV, de rebajas o de imagen.';

  @override
  String get chatTranscriptWelcomeMessage =>
      'Soy Rex. Cuéntame qué está pasando, qué cambió o qué quieres que recuerde.';

  @override
  String get rexViewOnDashboard => 'Ver en el Panel';

  @override
  String get rexRefreshAccounts => 'Actualizar cuentas';

  @override
  String get chatTranscriptReadyTitle => 'Rex está listo';

  @override
  String get chatTranscriptPromptRemember => '¿Qué debo recordar?';

  @override
  String get chatTranscriptPromptThinkTonight => 'Ayúdame a pensar esta noche.';

  @override
  String get chatTranscriptPromptCheckKnows => 'Comprueba lo que sabe Clarity.';

  @override
  String get chatBubbleClarityAction => 'Acción de claridad';

  @override
  String get voicePanelStartTalking => 'empezar a hablar';

  @override
  String get voicePanelProcessing => 'Tratamiento…';

  @override
  String voicePanelThinkingElapsed(String elapsed) {
    return 'Pensando · $elapsed';
  }

  @override
  String voicePanelThoughtFor(String elapsed) {
    return 'Pensó durante $elapsed';
  }

  @override
  String get voicePanelMuted => 'Apagado';

  @override
  String get voicePanelSettingsTooltip => 'Ajustes';

  @override
  String get voicePanelTryAgainTooltip => 'Intentar otra vez';

  @override
  String get voicePanelUnmuteMicTooltip => 'Activar micrófono';

  @override
  String get voicePanelMuteMicTooltip => 'Silenciar micrófono';

  @override
  String get voicePanelEndVoiceTooltip => 'Fin de voz';

  @override
  String get conversationListTitle => 'Charlas';

  @override
  String get conversationListDeleteTitle => '¿Eliminar conversación?';

  @override
  String get conversationListDeleteBody =>
      'Esto elimina la conversación y sus mensajes.';

  @override
  String get conversationListDeleteFailed =>
      'No se pudo eliminar la conversación.';

  @override
  String get conversationListDeletedSnackBar => 'Conversación eliminada';

  @override
  String get conversationListRenameTitle => 'Renombrar chat';

  @override
  String get conversationListRenameHint => 'Nombre del chat';

  @override
  String get conversationListRenameFailed => 'No se pudo renombrar el chat.';

  @override
  String get conversationListRenamedSnackBar => 'Chat renombrado';

  @override
  String get conversationListNewConversationTooltip => 'Nueva conversación';

  @override
  String get conversationListLoading => 'Cargando chats';

  @override
  String get conversationListEmptyTitle => 'Aún no hay chats';

  @override
  String get conversationListEmptyMessage =>
      'Inicie una nueva conversación cuando esté listo.';

  @override
  String get conversationListSearchHint => 'Buscar chats';

  @override
  String get conversationListClearSearchTooltip => 'Borrar búsqueda';

  @override
  String get conversationListSearching => 'Buscando chats';

  @override
  String get conversationListNoMatchesTitle => 'No hay chats coincidentes';

  @override
  String get conversationListNewChat => 'Nuevo chat';

  @override
  String get conversationHistoryNewConversation => 'Nueva conversación';

  @override
  String get conversationHistoryMatchedConversation =>
      'Conversación coincidente';

  @override
  String get conversationHistoryNoMessagesYet => 'Aún no hay mensajes';

  @override
  String get conversationHistoryActionsTooltip => 'Acciones de conversación';

  @override
  String get memoryPageTitle => 'Lo que la claridad sabe';

  @override
  String get memoryPageRefreshTooltip => 'Actualizar información';

  @override
  String get memoryPageMemoryUpdated => 'Memoria actualizada';

  @override
  String get memoryPageMemoryArchived => 'Memoria borrada';

  @override
  String get memoryPageActionFailed => 'La acción de la memoria falló.';

  @override
  String get memoryHeaderSearchHint => 'Busca lo que Clarity sabe';

  @override
  String get memoryHeaderClearSearchTooltip => 'Borrar búsqueda';

  @override
  String get memoryHeaderSectionTitle => 'Lo que la claridad sabe';

  @override
  String get memoryHeaderActiveOnly => 'Sólo información activa';

  @override
  String get memoryOverviewTruncated =>
      'Mostrando los primeros 50 elementos guardados en cada categoría. Desliza hacia abajo para actualizar.';

  @override
  String get memoryGroupFacts => 'Hechos';

  @override
  String get memoryGroupPreferences => 'Preferencias';

  @override
  String get memoryGroupPeople => 'Personas';

  @override
  String get memoryGroupPlaces => 'Lugares';

  @override
  String get memoryGroupGoals => 'Metas';

  @override
  String get memoryGroupRules => 'Reglas';

  @override
  String get memoryGroupEvents => 'Eventos';

  @override
  String get memoryGroupOther => 'Otros';

  @override
  String get memoryTypeFact => 'Hecho';

  @override
  String get memoryTypePreference => 'Preferencia';

  @override
  String get memoryTypeEvent => 'Evento';

  @override
  String get memoryTypeOther => 'Otra memoria';

  @override
  String get memoryEntityTypePlace => 'Lugar';

  @override
  String get memoryEntityTypeOrganization => 'Organización';

  @override
  String get memoryEditEditEntityTitle => 'Editar elemento guardado';

  @override
  String get memoryPageEntityUpdated => 'Elemento guardado actualizado';

  @override
  String get memoryOverviewLoadMore => 'Cargar más';

  @override
  String get memoryOverviewTruncatedMax =>
      'Mostrando los primeros 100 elementos guardados en cada categoría.';

  @override
  String get memoryRecordLongTermMemory => 'Nota de memoria';

  @override
  String get memoryRecordMemoryUpdate => 'Actualización de memoria';

  @override
  String get memoryRecordEntity => 'Persona / lugar';

  @override
  String get memoryRecordEntityEvent => 'Evento relacionado';

  @override
  String get memoryRecordPersonalRule => 'Regla';

  @override
  String get memoryRecordPlan => 'Plan';

  @override
  String get memoryRecordPlanMilestone => 'Hito';

  @override
  String get memoryRecordCorrection => 'Corrección';

  @override
  String get memoryRecordArchive => 'Borrar';

  @override
  String get memoryRecordMerge => 'Combinar';

  @override
  String get memoryRecordGentleDirect => 'Recordatorio amable';

  @override
  String get memoryRecordCheckpoint => 'Punto de control';

  @override
  String get memoryRecordApproved => 'Aprobado';

  @override
  String get memoryRecordApplied => 'Guardado';

  @override
  String get memoryRecordRejected => 'Rechazado';

  @override
  String get memoryRecordFailed => 'Necesita atención';

  @override
  String get memoryRecordSkipped => 'Omitido';

  @override
  String get memoryRecordActive => 'Activo';

  @override
  String get memoryRecordInactive => 'Inactivo';

  @override
  String get memoryRecordOpen => 'Abierto';

  @override
  String get memoryRecordCompleted => 'Completado';

  @override
  String get memoryRecordResolved => 'Resuelto';

  @override
  String get memoryRecordDismissed => 'Descartado';

  @override
  String get memoryRecordArchived => 'Borrado';

  @override
  String get memoryRecordLowRisk => 'Riesgo bajo';

  @override
  String get memoryRecordMediumRisk => 'Riesgo medio';

  @override
  String get memoryRecordHighRisk => 'Riesgo alto';

  @override
  String get memoryRecordCriticalRisk => 'Riesgo crítico';

  @override
  String get memoryRecordInfo => 'Información';

  @override
  String get memoryRecordEventNote => 'Nota';

  @override
  String get memoryRecordEventInteraction => 'Interacción';

  @override
  String get memoryRecordEventRelationshipUpdate => 'Actualización de relación';

  @override
  String get memoryRecordEventConflict => 'Conflicto';

  @override
  String get memoryRecordEventMilestone => 'Hito';

  @override
  String get memoryRecordProject => 'Proyecto';

  @override
  String get memoryRecordTask => 'Tarea';

  @override
  String get memoryHeaderLoading => 'Cargando memoria';

  @override
  String get memoryHeaderEmptyActiveTitle =>
      'La claridad todavía está aprendiendo.';

  @override
  String get memoryHeaderEmptyTitle => 'Aún no hay información guardada';

  @override
  String get memoryArchiveTitle => '¿Borrar información guardada?';

  @override
  String get memoryArchiveBody =>
      '¿Quitar esto de Knows? Rex dejará de usarlo en futuras conversaciones.';

  @override
  String get memoryTileActionsTooltip => 'Acciones de memoria';

  @override
  String get memoryTileQuickEdit => 'Edición rápida';

  @override
  String get memoryTileAddMilestone => 'Agregar hito';

  @override
  String get memoryEditEditMemoryTitle => 'Editar memoria';

  @override
  String get memoryEditSummaryHint => 'Lo que la claridad debe recordar.';

  @override
  String get accountabilityPageTitle => 'Objetivos';

  @override
  String get accountabilityPageRefreshTooltip => 'Actualizar objetivos';

  @override
  String get accountabilitySharedAddGoal => 'Añadir objetivo';

  @override
  String get accountabilitySharedAddOpenThread => 'Agregar hilo abierto';

  @override
  String get accountabilitySharedLoading => 'Cargando objetivos';

  @override
  String get accountabilitySharedEmptyTitle => 'Aún no hay goles';

  @override
  String get accountabilitySharedEmptyBody =>
      'Comience con un objetivo simple o dígaselo a Rex en el chat.';

  @override
  String get accountabilitySharedAddFirstGoal => 'Añade tu primer objetivo';

  @override
  String get accountabilitySectionsActiveGoals => 'Metas activas';

  @override
  String get accountabilitySectionsNoActiveGoals =>
      'Aún no hay objetivos activos.';

  @override
  String get accountabilitySectionsOpenThreads => 'Hilos abiertos';

  @override
  String get accountabilitySectionsNoOpenThreads =>
      'Aún no hay hilos abiertos.';

  @override
  String get accountabilitySectionsNeedsAttention => 'Necesita atención';

  @override
  String get accountabilitySectionsNoSignals =>
      'Nada requiere atención ahora mismo.';

  @override
  String get accountabilitySectionsRuleRisks => 'Riesgos de reglas';

  @override
  String get accountabilitySectionsNoRuleRisks =>
      'No se detectaron riesgos de reglas.';

  @override
  String get accountabilitySectionsRecentPatterns => 'Patrones recientes';

  @override
  String get accountabilitySectionsNoRecentPatterns =>
      'No hay patrones recientes para revisar.';

  @override
  String get accountabilityTilesGoalActionsTooltip => 'Acciones de objetivos';

  @override
  String get accountabilityTilesOpenThreadActionsTooltip =>
      'Acciones del hilo abierto';

  @override
  String get accountabilityTilesOpenThreadDefaultSubtitle =>
      'Seguimiento del compañero — no es memoria guardada';

  @override
  String get accountabilityTilesMarkMissed => 'marca perdida';

  @override
  String get accountabilityDetailGoalDetails => 'Detalles del objetivo';

  @override
  String get accountabilityDetailEditOpenThread => 'Editar hilo abierto';

  @override
  String get accountabilityDetailNotesHint => 'Por qué esto importa';

  @override
  String get budgetsScreenManageCategoriesTooltip => 'Administrar categorías';

  @override
  String get budgetsScreenSaveChangesTooltip => 'Guardar cambios';

  @override
  String get budgetsScreenLoadError =>
      'No se pudieron cargar los presupuestos.';

  @override
  String get budgetsScreenLoadingLabel => 'Cargando presupuestos';

  @override
  String get budgetsScreenBudgetVsSpentTitle => 'Presupuesto vs gastado';

  @override
  String get budgetsHeaderSelectMonth => 'Seleccionar mes';

  @override
  String get budgetsHeaderPickWeekStart => 'Elige el inicio de la semana';

  @override
  String get budgetsHeaderNoMonthsAvailable => 'No hay meses disponibles.';

  @override
  String get budgetsScreenUnsavedChangesTitle =>
      '¿Guardar cambios antes del período de cambio?';

  @override
  String get budgetsScreenUnsavedChangesContent =>
      'Tiene cambios de presupuesto no guardados para este período.';

  @override
  String get budgetsScreenSaveFailedSnack =>
      'No se pudieron ahorrar presupuestos. Intentar otra vez.';

  @override
  String get budgetCategoryListTitle => 'Categorías';

  @override
  String get budgetCategoryListEmpty =>
      'Aún no hay categorías de presupuesto activas.';

  @override
  String budgetCategoryRowStatusNoBudget(String spent) {
    return 'Gastado $spent · Sin presupuesto';
  }

  @override
  String budgetCategoryRowStatusOver(String spent, String amount) {
    return 'Gastado $spent · Más de $amount';
  }

  @override
  String budgetCategoryRowStatusLeft(String spent, String amount) {
    return 'Gastado $spent · Izquierdo $amount';
  }

  @override
  String get categorySheetHeaderTitle => 'Administrar categorías';

  @override
  String get categorySheetAddCustomCategory =>
      'Agregar categoría personalizada';

  @override
  String get categorySheetSavedCategoriesLabel => 'Categorías guardadas';

  @override
  String get categorySheetNoSavedCategories =>
      'Aún no hay categorías guardadas.';

  @override
  String get categorySheetMerchantRulesLabel => 'Reglas comerciales';

  @override
  String get categorySheetNoMerchantRules =>
      'Aún no hay reglas comerciales aprendidas.';

  @override
  String get categorySheetRecentChangesLabel => 'Cambios recientes';

  @override
  String get categorySheetNoAuditEvents =>
      'Aún no se han registrado cambios financieros.';

  @override
  String get categoryDialogNameLabel => 'Nombre de categoría';

  @override
  String get categorySheetAddCategoryTitle => 'Añadir categoría';

  @override
  String get categorySheetRenameCategoryTitle => 'Cambiar nombre de categoría';

  @override
  String get categorySheetDeleteCategoryTitle => '¿Eliminar categoría?';

  @override
  String get categorySheetMergeCategoryTitle => '¿Fusionar categoría?';

  @override
  String get categorySheetMergeButton => 'Unir';

  @override
  String get categorySheetCategoryInUseTitle => 'La categoría está en uso';

  @override
  String get categorySheetClose => 'Cerca';

  @override
  String get transactionCategoryAutoRole => 'rol automático';

  @override
  String get transactionCategoryFinancialRoleTooltip => 'Papel financiero';

  @override
  String get transactionCategoryNoCategories => 'Sin categorías';

  @override
  String get transactionCategoryNewCategoryHint => 'Nueva categoría';

  @override
  String get transactionCategoryOnlyThisOne => 'solo este';

  @override
  String get transactionCategoryUpdatedSnack => 'Categoría actualizada.';

  @override
  String budgetsScreenSavedSnack(String period) {
    return 'Presupuestos guardados para $period';
  }

  @override
  String get categorySheetLoadingLabel => 'Cargando categorías';

  @override
  String get categorySheetLoadError => 'No se pudieron cargar categorías.';

  @override
  String get categorySheetCategoryAddedSnack => 'Categoría agregada.';

  @override
  String get categorySheetCategoryRenamedSnack => 'Categoría renombrada.';

  @override
  String categorySheetDeleteCategoryContent(String name) {
    return '\"$name\" no se utiliza en transacciones, presupuestos ni reglas comerciales. ¿Eliminarlo de las categorías personalizadas guardadas?';
  }

  @override
  String get categorySheetCategoryDeletedSnack => 'Categoría eliminada.';

  @override
  String get categorySheetCategoryShownSnack =>
      'Categoría mostrada en selectores.';

  @override
  String get categorySheetCategoryHiddenSnack =>
      'Categoría oculta a los recolectores.';

  @override
  String categorySheetMergeCategoryContent(
    String source,
    String target,
    String usage,
  ) {
    return '¿Fusionar \"$source\" en \"$target\"? Esto moverá $usage a \"$target\" y eliminará \"$source\".';
  }

  @override
  String get categorySheetCategoryMergedSnack => 'Categoría fusionada.';

  @override
  String categorySheetCategoryInUseContent(String name, String usage) {
    return '\"$name\" es utilizado por $usage. Combínelo en otra categoría u ocultelo de los selectores en lugar de eliminarlo.';
  }

  @override
  String get categorySheetNoMergeTarget =>
      'No hay ninguna categoría de destino visible en la que fusionarse.';

  @override
  String categorySheetMergeIntoTitle(String source) {
    return 'Fusionar \"$source\" en';
  }

  @override
  String get categorySheetNoRuleCategory =>
      'No hay ninguna categoría visible disponible para esta regla.';

  @override
  String get categorySheetSetMerchantRuleCategoryTitle =>
      'Establecer categoría de regla comercial';

  @override
  String get categorySheetUpdateFutureImportsTitle =>
      '¿Actualizar futuras importaciones?';

  @override
  String categorySheetUpdateFutureImportsContent(
    String merchant,
    String category,
  ) {
    return 'Las futuras importaciones de \"$merchant\" utilizarán \"$category\". Las transacciones existentes no se modificarán.';
  }

  @override
  String get categorySheetUpdateRuleButton => 'Actualizar regla';

  @override
  String get categorySheetMerchantRuleUpdatedSnack =>
      'Regla comercial actualizada.';

  @override
  String get categorySheetDisableRuleTitle => '¿Desactivar regla?';

  @override
  String get categorySheetEnableRuleTitle => '¿Habilitar regla?';

  @override
  String categorySheetDisableRuleContent(String merchant) {
    return 'Las futuras importaciones de \"$merchant\" dejarán de utilizar esta regla de categoría aprendida.';
  }

  @override
  String categorySheetEnableRuleContent(String merchant) {
    return 'Las futuras importaciones de \"$merchant\" volverán a utilizar esta regla de categoría aprendida.';
  }

  @override
  String get categorySheetMerchantRuleDisabledSnack =>
      'Regla de comerciante deshabilitada.';

  @override
  String get categorySheetMerchantRuleEnabledSnack =>
      'Regla de comerciante habilitada.';

  @override
  String get categorySheetDeleteMerchantRuleTitle =>
      '¿Eliminar regla comercial?';

  @override
  String categorySheetDeleteMerchantRuleContent(String merchant) {
    return 'Las importaciones futuras de \"$merchant\" ya no utilizarán esta regla de categoría aprendida.';
  }

  @override
  String get categorySheetMerchantRuleDeletedSnack =>
      'Se eliminó la regla del comerciante.';

  @override
  String categorySheetSaveFailedSnack(String error) {
    return 'No se pudieron guardar los cambios: $error';
  }

  @override
  String categorySheetBuiltInHint(int count) {
    return 'Las categorías de presupuesto integradas siempre están disponibles: $count. Las categorías personalizadas utilizadas deben fusionarse u ocultarse antes de eliminarlas.';
  }

  @override
  String get categorySheetMerchantRulesHint =>
      'Las reglas comerciales afectan las futuras importaciones de CSV. La edición de una regla no reescribe las transacciones existentes.';

  @override
  String get categorySheetCategoryActionsTooltip => 'Acciones de categoría';

  @override
  String get categorySheetShowInPickers => 'Mostrar en selectores';

  @override
  String get categorySheetHideFromPickers => 'Esconderse de los recolectores';

  @override
  String get commonRename => 'Rebautizar';

  @override
  String get categorySheetChangeCategory => 'Cambiar categoría';

  @override
  String get categorySheetEnableRule => 'Habilitar regla';

  @override
  String get categorySheetDisableRule => 'Deshabilitar regla';

  @override
  String get categorySheetDeleteRule => 'Eliminar regla';

  @override
  String get categorySheetMerchantRuleActionsTooltip =>
      'Acciones de reglas comerciales';

  @override
  String get categorySheetMissingCategory => 'Categoría faltante';

  @override
  String get categorySheetAuditTransactionCategoryChanged =>
      'La categoría de transacción cambió';

  @override
  String get categorySheetAuditBulkCategoryChange =>
      'Cambio de categoría masiva';

  @override
  String get categorySheetAuditTransactionRoleChanged =>
      'El rol de transacción cambió';

  @override
  String get categorySheetAuditCategoryDeleted => 'Categoría eliminada';

  @override
  String get categorySheetAuditCategoryMerged => 'Categoría fusionada';

  @override
  String get categorySheetAuditCategoryVisibilityChanged =>
      'La visibilidad de la categoría cambió';

  @override
  String get categorySheetAuditMerchantRuleChanged =>
      'La regla del comerciante cambió';

  @override
  String get categorySheetAuditMerchantRuleEnabledDisabled =>
      'Regla de comerciante habilitada/deshabilitada';

  @override
  String get categorySheetAuditMerchantRuleDeleted =>
      'Regla de comerciante eliminada';

  @override
  String get categorySheetAuditCategoryRenamed => 'Categoría renombrada';

  @override
  String categoryUsageTxCount(int count) {
    return '$count tx';
  }

  @override
  String categoryUsageBudgetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presupuestos',
      one: '1 presupuesto',
    );
    return '$_temp0';
  }

  @override
  String categoryUsageRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas',
      one: '1 regla',
    );
    return '$_temp0';
  }

  @override
  String merchantRuleStatsMatchingTx(int count) {
    return '$count transmisión coincidente';
  }

  @override
  String merchantRuleStatsMatchingTxLastUsed(int count, String date) {
    return '$count transmisión coincidente · último uso $date';
  }

  @override
  String get transactionCategoryNotFoundSnack =>
      'No se pudo encontrar esta transacción.';

  @override
  String transactionCategoryUpdateRoleFailed(String error) {
    return 'No se pudo actualizar el rol: $error';
  }

  @override
  String transactionCategoryDeleteTitle(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get transactionCategoryDeleteContent =>
      '¿Eliminar esta categoría y borrarla de las transacciones asignadas?';

  @override
  String transactionCategoryUpdateFailed(String error) {
    return 'No se pudo actualizar la categoría: $error';
  }

  @override
  String get transactionCategoryApplySimilarTitle =>
      '¿Aplicar a transacciones similares?';

  @override
  String transactionCategoryApplySimilarContent(int count, String merchant) {
    return 'Clarity encontró $count transacciones que se parecen a \"$merchant\". ¿Aplicar esta categoría a todos ellos y recordarla para futuras importaciones de CSV?';
  }

  @override
  String transactionCategoryUpdateCount(int count) {
    return 'Actualizar $count';
  }

  @override
  String transactionCategoryUpdatedSimilarSnack(int count) {
    return 'Se actualizaron $count transacciones similares. Elija otra categoría para corregirlos.';
  }

  @override
  String get transactionCategoryUpdatedFutureImportsSnack =>
      'Categoría actualizada. Las futuras importaciones coincidentes lo utilizarán.';

  @override
  String get importJobCompleteSnack => 'Importación completa.';

  @override
  String importJobCategoryAssignmentFailedSnack(int inserted) {
    return 'Se importaron $inserted transacciones, pero falló la asignación de categoría.';
  }

  @override
  String importJobCategoryRetryNeededPersistent(int inserted, int failures) {
    return 'Se importaron $inserted transacciones, pero $failures necesita un reintento de asignación de categoría.';
  }

  @override
  String get importJobNeedsCategoryRetryTitle =>
      'La importación necesita un reintento de categoría';

  @override
  String importJobNoNewTransactionsDuplicates(int skipped) {
    return 'No se importaron nuevas transacciones. $skipped duplicados omitidos.';
  }

  @override
  String get importJobNoNewTransactions =>
      'No se importaron nuevas transacciones.';

  @override
  String importJobSuccessWithLocalAndMisc(int inserted, int local, int misc) {
    return 'Transacciones $inserted importadas. Categorizado todo; $local usó reglas locales; $misc utilizó una categoría de mejor suposición.';
  }

  @override
  String importJobSuccessWithLocal(int inserted, int local) {
    return 'Transacciones $inserted importadas. Categorizado todo; $local usó reglas locales.';
  }

  @override
  String importJobSuccessWithMisc(int inserted, int misc) {
    return 'Transacciones $inserted importadas. Categorizado todo; $misc utilizó una categoría de mejor suposición.';
  }

  @override
  String importJobSuccessCategorizedAll(int inserted) {
    return 'Transacciones $inserted importadas. Categorizó todas las transacciones.';
  }

  @override
  String get importJobFailedTitle => 'Importación fallida';

  @override
  String get importJobRetryingCategoryAssignment =>
      'Reintentando la asignación de categoría...';

  @override
  String get importJobCategoryRetryCompleteProgress =>
      'Reintento de categoría completo.';

  @override
  String get importJobNoRetryableRowsSnack =>
      'No se encontraron filas de categorías reintentables.';

  @override
  String get importJobNoRetryableRowsTitle => 'No hay filas reintentables';

  @override
  String importJobRetriedCategoriesSnack(int count) {
    return 'Categorías reintentadas. Transacciones $count actualizadas.';
  }

  @override
  String get importJobCategoryRetryCompleteTitle =>
      'Reintento de categoría completo';

  @override
  String get importJobCategoryRetryFailedProgress =>
      'Error al reintentar la categoría.';

  @override
  String importJobCategoryRetryFailedSnack(String error) {
    return 'No se pudo volver a intentar la asignación de categoría: $error';
  }

  @override
  String get importJobCategoryRetryFailedTitle =>
      'Error al reintentar la categoría';

  @override
  String importJobRetryFailedLine(String error) {
    return 'Reintento fallido: $error';
  }

  @override
  String importJobSummaryParsedLine(int parsed, int inserted, int skipped) {
    return 'Analizado $parsed; importado $inserted; omitió $skipped duplicados.';
  }

  @override
  String importJobSummaryAiLine(String status, int aiRows, int localRows) {
    return 'IA $status; Filas AI $aiRows; filas de reglas locales $localRows.';
  }

  @override
  String importJobSummaryCategoriesLine(int misc, int failures) {
    return 'Categorías de mejores conjeturas $misc; Errores de actualización de categoría $failures.';
  }

  @override
  String importJobSummaryScannedLine(int scanned, int retryable) {
    return 'Escaneado $scanned; reintentable $retryable.';
  }

  @override
  String importJobSummaryUpdatedLine(int updated, int remaining) {
    return 'Actualizado $updated; todavía sin categoría $remaining.';
  }

  @override
  String get importJobAiStatusCompleted => 'terminado';

  @override
  String get importJobAiStatusUnavailable => 'indisponible';

  @override
  String get mfaEnrollmentAppBarTitle => 'Autenticación multifactor';

  @override
  String get mfaEnrollmentTurnOffTitle => '¿Desactivar MFA?';

  @override
  String get mfaEnrollmentCancel => 'Cancelar';

  @override
  String get mfaEnrollmentTurnOff => 'Apagar';

  @override
  String get mfaEnrollmentAuthenticatorApps => 'Aplicaciones de autenticación';

  @override
  String get mfaEnrollmentMfaOn => 'MFA está en marcha';

  @override
  String get mfaEnrollmentMfaOff => 'MFA está desactivado';

  @override
  String get mfaEnrollmentTurnOnMfa => 'Activar MFA';

  @override
  String get mfaEnrollmentSetupTitle =>
      'Configurar la aplicación de autenticación';

  @override
  String get mfaEnrollmentCodeLabel => 'código de 6 dígitos';

  @override
  String get mfaEnrollmentEnableMfa => 'Habilitar MFA';

  @override
  String get mfaVerificationTitle => 'Ingrese su código MFA';

  @override
  String get mfaVerificationSubtitle =>
      'Abra su aplicación de autenticación e ingrese el código actual de 6 dígitos para Clarity.';

  @override
  String get mfaVerificationAuthenticatorAppLabel =>
      'Aplicación de autenticación';

  @override
  String get mfaVerificationVerifyAndContinue => 'Verificar y continuar';

  @override
  String get mfaEnterSixDigitCode => 'Ingrese el código de 6 dígitos.';

  @override
  String get mfaEnrollmentTurnOffBodySingle =>
      'Su cuenta ya no le solicitará un código de autenticación después de iniciar sesión con contraseña.';

  @override
  String mfaEnrollmentTurnOffBodyMultiple(int factorCount) {
    return 'Esto elimina todas las aplicaciones de autenticación $factorCount. Su cuenta ya no le solicitará un código de autenticación después de iniciar sesión con contraseña.';
  }

  @override
  String get mfaEnrollmentRemoveTitle => '¿Eliminar MFA?';

  @override
  String mfaEnrollmentRemoveBody(String factorName) {
    return '¿Quitar $factorName? Puede registrar otra aplicación de autenticación más adelante.';
  }

  @override
  String get mfaEnrollmentAddAnotherApp => 'Agregar otra aplicación';

  @override
  String get mfaEnrollmentMfaOnDescription =>
      'Su cuenta requiere un código de autenticación después de iniciar sesión con contraseña.';

  @override
  String get mfaEnrollmentMfaOffDescription =>
      'Agregue una aplicación de autenticación para proteger su espacio de trabajo financiero.';

  @override
  String get mfaEnrollmentSetupInstructions =>
      'Escanee este código QR en 1Password, Google Authenticator, Authy u otra aplicación TOTP.';

  @override
  String get mfaEnrollmentCopyAuthenticatorUri => 'Copiar URI del autenticador';

  @override
  String get mfaEnrollmentManualSetupKey => 'Tecla de configuración manual';

  @override
  String get mfaEnrollmentCopyManualSetupKeyTooltip =>
      'Copiar clave de configuración manual';

  @override
  String get mfaEnrollmentRemoveAuthenticatorTooltip =>
      'Eliminar la aplicación de autenticación';

  @override
  String get mfaEnrollmentRecoveryNotice =>
      'Supabase Auth no proporciona códigos de recuperación para TOTP. Agregue una segunda aplicación de autenticación como respaldo antes de eliminar su único factor.';

  @override
  String get mfaEnrollmentManualSetupKeyCopyLabel =>
      'Tecla de configuración manual';

  @override
  String get mfaEnrollmentAuthenticatorUriCopyLabel => 'URI del autenticador';

  @override
  String get authErrorInvalidCredentials =>
      'El correo electrónico o la contraseña son incorrectos. Inténtalo de nuevo o crea una cuenta nueva.';

  @override
  String get authErrorAccountExists =>
      'Ya existe una cuenta con este correo electrónico. Inicia sesión en su lugar.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Primero confirme su correo electrónico y luego inicie sesión.';

  @override
  String get authErrorEmailSendFailed =>
      'No pudimos enviar un correo electrónico de confirmación en este momento. Vuelva a intentarlo en unos minutos o comuníquese con el soporte técnico si esto continúa.';

  @override
  String get authErrorSignupsDisabled =>
      'El registro de nueva cuenta está deshabilitado para esta aplicación en este momento.';

  @override
  String get authErrorWeakPassword =>
      'Elija una contraseña más segura e inténtelo de nuevo.';

  @override
  String get authErrorMfaCodeRejected =>
      'Ese código no fue aceptado. Verifique su aplicación de autenticación e inténtelo nuevamente.';

  @override
  String get authErrorMfaNotEnabled =>
      'MFA no está habilitado para este proyecto de Supabase.';

  @override
  String get authErrorTooManyAttempts =>
      'Demasiados intentos. Espere un momento y vuelva a intentarlo.';

  @override
  String get authErrorNoAuthenticatorAvailable =>
      'No hay ninguna aplicación de autenticación verificada disponible para esta cuenta.';

  @override
  String get authErrorStartEnrollmentFirst =>
      'Inicie la inscripción en MFA antes de verificar un código.';

  @override
  String get authInfoAccountCreatedSignedIn =>
      'Cuenta creada. Has iniciado sesión.';

  @override
  String authInfoConfirmationLinkSent(String email) {
    return 'Enviamos un enlace de confirmación a $email. Ábrelo para confirmar, luego vuelve aquí e inicia sesión.';
  }

  @override
  String get authInfoEnterAuthenticatorCode =>
      'Ingrese su código de autenticación para terminar de iniciar sesión.';

  @override
  String authInfoPasswordResetSent(String email) {
    return 'Si existe una cuenta para $email, le enviamos un enlace para restablecer la contraseña.';
  }

  @override
  String get authInfoMfaEnrollmentStart =>
      'Escanee el código QR y luego ingrese el código de 6 dígitos desde su aplicación.';

  @override
  String get authInfoMfaEnabledEmailSent =>
      'MFA está habilitado. Le enviamos un correo electrónico de confirmación.';

  @override
  String get authInfoMfaEnabledEmailFailed =>
      'MFA está habilitado. El correo electrónico de confirmación no se pudo enviar en este momento.';

  @override
  String get authInfoMfaDisabledEmailSent =>
      'El MFA está desactivado. Le enviamos un correo electrónico de confirmación.';

  @override
  String get authInfoMfaDisabledEmailFailed =>
      'El MFA está desactivado. El correo electrónico de confirmación no se pudo enviar en este momento.';

  @override
  String get authInfoSignInVerified => 'Inicio de sesión verificado.';

  @override
  String get authInfoAuthenticatorRemoved =>
      'Se eliminó la aplicación de autenticación.';

  @override
  String get authInfoMfaAlreadyOff => 'El MFA ya está en marcha.';

  @override
  String get importProgressImporting => 'Importador...';

  @override
  String get importProgressCategorizing => 'Categorizando...';

  @override
  String get importProgressSavingCategories => 'Guardando categorías...';

  @override
  String get importProgressApplyingFallbackCategories =>
      'Aplicando categorías alternativas...';

  @override
  String get importProgressRefreshing => 'Refrescante...';

  @override
  String get usageChartNoDailyVoiceUsage => 'Aún no hay uso diario de voz.';

  @override
  String get usageChartNotEnoughRadarData =>
      'No hay suficientes datos de uso para el gráfico de radar.';

  @override
  String get usageChartNoDailyCallData =>
      'Aún no hay datos de llamadas diarias.';

  @override
  String get usageChartDayMon => 'Lun';

  @override
  String get usageChartDayTue => 'Mar';

  @override
  String get usageChartDayWed => 'Casarse';

  @override
  String get usageChartDayThu => 'Jue';

  @override
  String get usageChartDayFri => 'Vie';

  @override
  String get usageChartDaySat => 'Se sentó';

  @override
  String get usageChartDaySun => 'Sol';

  @override
  String get commonNone => 'Ninguno';

  @override
  String dashboardBudgetNoBudgetsForPeriod(String periodLabel) {
    return 'Aún no se han establecido presupuestos para $periodLabel.';
  }

  @override
  String dashboardBudgetCategoriesOnTrack(int onTrack, int budgeted) {
    return '$onTrack/$budgeted categorías en camino';
  }

  @override
  String dashboardBudgetTotalOverspent(String amount) {
    return 'Gasto excesivo total $amount';
  }

  @override
  String dashboardBudgetBudgetedSpentLine(String budgeted, String spent) {
    return 'Presupuestado $budgeted / Gastado $spent';
  }

  @override
  String get dashboardBudgetNoOverspendingCategories =>
      'No hay categorías de gasto excesivo en este período.';

  @override
  String dashboardBudgetCategoryOverspent(String label, String amount) {
    return '$label: gastado de más $amount';
  }

  @override
  String dashboardHealthSpendingAheadOfIncome(String amount) {
    return 'El gasto está por delante de los ingresos en $amount este mes.';
  }

  @override
  String dashboardHealthIncomeAheadOfSpending(String amount) {
    return 'Los ingresos están por delante de los gastos en $amount este mes.';
  }

  @override
  String get dashboardHealthSpendingActiveNoIncome =>
      'El gasto está activo este mes; No se registran ingresos en este ámbito.';

  @override
  String get dashboardHealthIncomeNoSpending =>
      'Se registran ingresos y aún no se han registrado gastos para este mes.';

  @override
  String get dashboardHealthNoCurrentMonthActivity =>
      'Aún no hay actividad en este ámbito en el mes en curso.';

  @override
  String get dashboardHealthConnectTransactions =>
      'Conecte transacciones para mejorar la salud de la cuenta.';

  @override
  String get dashboardHealthNoBudgets => 'Sin presupuestos';

  @override
  String get dashboardHealthSetBudgets =>
      'Establezca presupuestos para comparar este mes con un objetivo.';

  @override
  String dashboardHealthCategoryOverBy(String label, String amount) {
    return '$label terminó por $amount.';
  }

  @override
  String dashboardHealthBudgetControlled(String periodLabel) {
    return 'La cobertura presupuestaria parece controlada para $periodLabel.';
  }

  @override
  String get dashboardHealthNoSpendingPressure =>
      'No se registró presión de gasto este mes.';

  @override
  String dashboardHealthTopSpendPressure(String name) {
    return '$name es la mayor presión de gasto este mes.';
  }

  @override
  String get dashboardHealthThisMonthNet => 'Este mes neto';

  @override
  String get dashboardHealthSpendPressureLabel => 'Gastar presión';

  @override
  String get dashboardHealthBudgetCoverageLabel => 'Cobertura presupuestaria';

  @override
  String get dashboardHealthBurnRunwayLabel => 'Reserva de efectivo';

  @override
  String dashboardHealthBurnRunwayDays(int days) {
    return '$days días';
  }

  @override
  String dashboardHealthBurnRunwayDetail(int days) {
    return 'Al ritmo de gasto de este mes, su saldo dura unos $days días.';
  }

  @override
  String get dashboardOverviewBudgetVsSpentChart => 'Presupuesto vs gastado';

  @override
  String dashboardHealthIncomeSpendingLine(String income, String spending) {
    return 'Ingresos $income / Gastos $spending';
  }

  @override
  String get dashboardChartConnectAccountsCashFlow =>
      'Conecte cuentas para ver el flujo de caja mensual.';

  @override
  String get dashboardChartNoCategorySpending =>
      'Aún no hay gasto de categoría.';

  @override
  String get dashboardChartNoSpendingPressure =>
      'No hay presión de gasto este mes.';

  @override
  String get dashboardChartNoBudgetCategories =>
      'No hay categorías de presupuesto para trazar.';

  @override
  String get dashboardChartNoSpendingHistory =>
      'Aún no hay historial de gastos.';

  @override
  String get dashboardChartNoIncomeOrSpending =>
      'No hay ingresos ni gastos este mes.';

  @override
  String dashboardChartIncomeSpendingSummary(String income, String spent) {
    return 'Ingresos $income · Gastos $spent';
  }

  @override
  String get monthDetailDeleteMonthTooltip => 'Eliminar este mes';

  @override
  String monthDetailDeleteMonthTitle(String monthLabel) {
    return '¿Eliminar $monthLabel transacciones?';
  }

  @override
  String monthDetailDeleteMonthBody(
    int count,
    String transactionSuffix,
    String monthLabel,
  ) {
    return 'Esto eliminará permanentemente la $count transacción visible $transactionSuffix para esta cuenta en $monthLabel. Otros meses permanecerán intactos.';
  }

  @override
  String get monthDetailDeleteMonthButton => 'Eliminar mes';

  @override
  String monthDetailDeletedTransactions(
    int count,
    String monthLabel,
    String transactionSuffix,
  ) {
    return 'Se eliminó $count $monthLabel transacción$transactionSuffix.';
  }

  @override
  String get monthDetailNothingDeleted => 'No se eliminaron transacciones.';

  @override
  String get monthDetailLoadingMonth => 'Mes de carga';

  @override
  String get monthDetailNetThisMonth => 'NETO ESTE MES';

  @override
  String get monthDetailNoTransactionsLeft =>
      'No quedan transacciones para este mes.';

  @override
  String get monthDetailDeleteTransactionTooltip => 'Eliminar transacción';

  @override
  String get monthDetailDeleteTransactionTitle => '¿Eliminar esta transacción?';

  @override
  String get monthDetailDeleteTransactionBody =>
      'Esta transacción se eliminará permanentemente.';

  @override
  String get monthDetailTransactionDeleted => 'Transacción eliminada.';

  @override
  String get monthDetailDeleteTransactionFailed =>
      'No se pudo eliminar la transacción.';

  @override
  String get monthDetailPlaidDeleteProtection =>
      'Las transacciones a cuadros se sincronizan desde su banco. Utilice resincronización o desconexión en lugar de eliminación local.';

  @override
  String get accountsScreenNoActiveConnectionRefresh =>
      'No hay conexión bancaria activa para actualizar.';

  @override
  String get accountsScreenCouldNotRefreshAccounts =>
      'No se pudieron actualizar las cuentas conectadas.';

  @override
  String get accountsScreenDisconnectedConnection =>
      'Esta conexión bancaria está desconectada.';

  @override
  String get accountsScreenCouldNotRefreshAccount =>
      'No se pudo actualizar esta cuenta.';

  @override
  String get accountsScreenCouldNotDisconnect =>
      'No se pudo desconectar este banco.';

  @override
  String accountsScreenDisconnectedNotice(String institutionName) {
    return '$institutionName desconectado. La sincronización futura de Plaid se detiene.';
  }

  @override
  String get plaidAccountStatusConnected => 'Conectado';

  @override
  String get plaidAccountStatusDegradedLabel => 'Degradado';

  @override
  String get plaidAccountStatusNeedsLogin => 'Necesita iniciar sesión';

  @override
  String get plaidAccountStatusRefreshing =>
      'Actualizando esta conexión bancaria ahora.';

  @override
  String get plaidAccountStatusDegradedMessage =>
      'La sincronización necesita atención. Intente actualizar; Si aún falla, vuelva a conectar este banco en Plaid.';

  @override
  String get plaidAccountStatusLoginRequiredMessage =>
      'Plaid necesita que inicies sesión nuevamente. Conecte este banco nuevamente para reanudar la sincronización.';

  @override
  String get plaidAccountStatusExpiringSoonMessage =>
      'Esta conexión a cuadros puede caducar pronto. Actualice ahora o vuelva a conectarse si la sincronización se detiene.';

  @override
  String get plaidAccountStatusDisconnectedMessage =>
      'La sincronización futura de Plaid se detiene. El historial de la cuenta existente permanece en Clarity.';

  @override
  String get plaidAccountNoWebhookYet =>
      'Aún no ha llegado ningún webhook de Plaid. Utilice la actualización si las transacciones parecen obsoletas.';

  @override
  String plaidAccountNoRecentWebhook(String relativeTime) {
    return 'No hay ningún webhook reciente de Plaid. La última señal de actualización del banco fue $relativeTime.';
  }

  @override
  String plaidAccountWebhookDaysAgo(int days) {
    return 'Hace ${days}d';
  }

  @override
  String plaidAccountWebhookHoursAgo(int hours) {
    return '__TOKHace 0__h';
  }

  @override
  String plaidAccountWebhookMinutesAgo(int minutes) {
    return '__TOKHace 0__m';
  }

  @override
  String get plaidAccountWebhookJustNow => 'En este momento';

  @override
  String get accountDetailNoCsvUploads =>
      'No se encontraron cargas CSV para esta cuenta.';

  @override
  String accountDetailDeleteCsvBody(int count, String transactionSuffix) {
    return '¿Eliminar $count transacción $transactionSuffix de esta carga? Esto no se puede deshacer.';
  }

  @override
  String accountDetailDeletedFromCsv(int deleted, String transactionSuffix) {
    return 'Se eliminó $deleted transacción$transactionSuffix de la carga de CSV.';
  }

  @override
  String get accountDetailCsvAlreadyDeleted => 'La carga CSV ya se eliminó.';

  @override
  String get accountDetailCouldNotDeleteCsv =>
      'No se pudo eliminar la carga CSV.';

  @override
  String get accountDetailCouldNotDeleteAccount =>
      'No se pudo eliminar la cuenta.';

  @override
  String accountDetailAccountDeleted(String accountName, String cleanupNote) {
    return '$accountName eliminado.$cleanupNote';
  }

  @override
  String accountDetailRemovedBudgets(int count, String budgetSuffix) {
    return 'Se eliminó $count presupuesto no utilizado $budgetSuffix.';
  }

  @override
  String accountDetailDeleteUnusedCategoryTitle(String plural) {
    return '¿Eliminar el $plural personalizado no utilizado?';
  }

  @override
  String accountDetailDeleteUnusedCategorySingle(String name) {
    return '\"$name\" ya no tiene transacciones activas después de eliminar esta cuenta. ¿Eliminar también esta categoría personalizada?';
  }

  @override
  String accountDetailDeleteUnusedCategoryMultiple(String names) {
    return 'Estas categorías personalizadas ya no tienen transacciones activas después de eliminar esta cuenta: $names. ¿Eliminarlos también?';
  }

  @override
  String accountDetailUploadBatchLabel(String importId) {
    return 'Subir $importId';
  }

  @override
  String get accountDetailCategorySingular => 'categoría';

  @override
  String get accountDetailCategoriesPlural => 'categorias';

  @override
  String get csvPreviewPlaidOverlapHint =>
      'Esta cuenta conectada ya se sincroniza a través de Plaid. Importe solo si este CSV cubre filas que Clarity aún no tiene.';

  @override
  String get csvPreviewManualFallbackHint =>
      'Esta es una importación alternativa manual. Es posible que tengas que cargar archivos CSV más nuevos más adelante para mantener esta cuenta actualizada.';

  @override
  String get csvPreviewLayoutInferred =>
      'Se infirió el diseño de las columnas. Revise el rango de fechas antes de importar.';

  @override
  String get csvPreviewDuplicateImport =>
      'Parece una importación duplicada para esta cuenta. Elija otra cuenta o elimine la carga CSV anterior de la página de la cuenta antes de volver a intentarlo.';

  @override
  String get accountSelectionManualAccountForCsv =>
      'Agregar una cuenta manual para este CSV';

  @override
  String get assistantTabChat => 'Chat';

  @override
  String get assistantTabKnows => 'sabe';

  @override
  String get assistantTabGoals => 'Objetivos';

  @override
  String get assistantTabOverview => 'Resumen';

  @override
  String get assistantTabChats => 'Chats';

  @override
  String get assistantOverviewTitle => 'Resumen del compañero';

  @override
  String get assistantOverviewSubtitle =>
      'Reglas, patrones, hilos abiertos y objetivos que Rex sigue contigo.';

  @override
  String get assistantOverviewBrowseChats => 'Ver chats';

  @override
  String get assistantChatSidebarHideTooltip => 'Ocultar chats';

  @override
  String get assistantChatSidebarShowTooltip => 'Mostrar chats';

  @override
  String get assistantOverviewAttentionTitle => 'Qué vigilar';

  @override
  String get assistantOverviewAttentionEmpty => 'Nada necesita atención ahora.';

  @override
  String get assistantOverviewRulesTitle => 'Reglas activas';

  @override
  String get assistantOverviewRulesEmpty =>
      'Aún no hay reglas activas. Guarda una en Sabe o pídeselo a Rex.';

  @override
  String get assistantOverviewThreadsTitle => 'Hilos abiertos';

  @override
  String get assistantOverviewThreadsEmpty =>
      'No hay hilos abiertos. Los hábitos y seguimientos aparecerán aquí.';

  @override
  String get assistantOverviewGoalsTitle => 'Objetivos activos';

  @override
  String get assistantOverviewGoalsEmpty =>
      'Aún no hay objetivos activos. Añade uno en Objetivos o pídeselo a Rex.';

  @override
  String assistantTabSemanticLabel(String tab) {
    return 'Pestaña Asistente $tab';
  }

  @override
  String get voicePanelVoiceMuted => 'Voz silenciada';

  @override
  String get voicePanelVoiceReady => 'Voz lista';

  @override
  String get voicePanelListening => 'Escuchando';

  @override
  String get voicePanelThinking => 'Pensamiento';

  @override
  String get voicePanelSpeaking => 'Discurso';

  @override
  String get voicePanelVoicePaused => 'Voz en pausa';

  @override
  String get voiceSessionReturnToChat => 'Volver al chat de Assistant';

  @override
  String get voiceFailureSessionReconnect =>
      'Su sesión de Clarity debe volver a conectarse antes de que la voz pueda continuar. Inicie sesión nuevamente si esto continúa sucediendo.';

  @override
  String get voiceFailureMicrophoneAccess =>
      'Se necesita acceso al micrófono para la voz. Verifique la configuración y vuelva a intentarlo.';

  @override
  String get voiceFailureDidNotCatch =>
      'No entendí eso. Toca Intentar de nuevo cuando estés listo.';

  @override
  String get voiceFailureConnectionDropped =>
      'Se cayó la conexión de voz. Toque Intentar nuevamente para volver a conectarse.';

  @override
  String get voiceFailureTranscriptUnreadable =>
      'No pude leer esa transcripción. Toca Intentar de nuevo y dilo una vez más.';

  @override
  String get voiceFailurePlaybackFailed =>
      'Rex respondió, pero no pude reproducir el audio. Toque Intentar nuevamente para escuchar la respuesta.';

  @override
  String get voiceFailurePausedDefault =>
      'La voz se detuvo. Toque Intentar nuevamente cuando esté listo para continuar.';

  @override
  String get memoryHeaderEmptyActiveBody =>
      'Agrega algo aquí, o pídele a Rex en el chat o por voz que lo guarde.';

  @override
  String get memoryHeaderEmptyBody =>
      'Aquí aparecerán los datos, las personas y las preferencias guardadas.';

  @override
  String get memoryHeaderEmptyAddAction => 'Agregar información guardada';

  @override
  String get memoryHeaderNoMatchingTitle => 'No hay información coincidente';

  @override
  String get memoryHeaderNoMatchingBody => 'Pruebe con otra búsqueda o filtro.';

  @override
  String get memoryPagePersonUpdated => 'Persona actualizada';

  @override
  String get memoryPageRuleUpdated => 'Regla actualizada';

  @override
  String get memoryPagePlanUpdated => 'Plan actualizado';

  @override
  String get memoryCreateAddTooltip => 'Agregar información guardada';

  @override
  String get memoryCreateChooseType => '¿Qué debe recordar Clarity?';

  @override
  String get memoryCreateFact => 'Hecho';

  @override
  String get memoryCreatePreference => 'Preferencia';

  @override
  String get memoryCreateRule => 'Regla';

  @override
  String get memoryCreatePlan => 'Plan';

  @override
  String get memoryCreateFactTitle => 'Agregar un hecho';

  @override
  String get memoryCreatePreferenceTitle => 'Agregar una preferencia';

  @override
  String get memoryCreatePersonTitle => 'Agregar una persona';

  @override
  String get memoryCreateRuleTitle => 'Agregar una regla';

  @override
  String get memoryCreatePlanTitle => 'Agregar un plan';

  @override
  String get memoryCreateCategoryLabel => 'Categoría';

  @override
  String get memoryCreateRelationshipLabel => 'Relación';

  @override
  String get memoryCreateSave => 'Guardar en Lo que sabe';

  @override
  String get memoryPageMemoryCreated => 'Guardado en Lo que sabe';

  @override
  String get memoryPagePersonCreated => 'Persona guardada';

  @override
  String get memoryPageRuleCreated => 'Regla guardada';

  @override
  String get memoryPagePlanCreated => 'Plan guardado';

  @override
  String get memoryPageMilestoneCreated => 'Hito guardado';

  @override
  String get memoryPageMilestoneUpdated => 'Hito actualizado';

  @override
  String get memoryCreateMilestoneTitle => 'Agregar un hito';

  @override
  String get memoryEditEditMilestoneTitle => 'Editar hito';

  @override
  String get memoryEditEditPersonTitle => 'Editar persona';

  @override
  String get memoryEditPersonRelationshipHint =>
      'Relación — p. ej. amigo, compañero, hermana';

  @override
  String get memoryEditPersonRelationshipHelper =>
      'Clarity usa esto como tipo de relación.';

  @override
  String get memoryEditPersonBirthdayHint => 'mm/dd/aaaa';

  @override
  String memoryEditPersonDeleteBody(String name) {
    return '¿Quitar a $name de Knows? Esto archiva la tarjeta de persona.';
  }

  @override
  String get memoryEditEditRuleTitle => 'Editar regla';

  @override
  String get memoryEditEditPlanTitle => 'Editar plan';

  @override
  String get memoryEditRuleTextLabel => 'Texto de regla';

  @override
  String get memoryEditTriggerKeywordsLabel => 'Palabras clave desencadenantes';

  @override
  String get memoryEditDesiredOutcomeLabel => 'Resultado deseado';

  @override
  String get memoryEditAliasesLabel => 'Alias';

  @override
  String memoryArchiveNamedTitle(String label) {
    return '¿Borrar $label?';
  }

  @override
  String memoryArchiveStructuredBody(String label) {
    return '¿Quitar este $label de Knows? Rex dejará de usarlo como contexto activo.';
  }

  @override
  String get memoryDisplayLocation => 'Ubicación';

  @override
  String get memoryDisplayBirthday => 'Cumpleaños';

  @override
  String get memoryDisplayJob => 'Trabajo';

  @override
  String get memoryDisplayWorkplace => 'Lugar de trabajo';

  @override
  String get memoryDisplayImportantDate => 'fecha importante';

  @override
  String get accountabilityAddGoalTitle => 'Añadir objetivo';

  @override
  String get accountabilityAddOpenThreadTitle => 'Agregar hilo abierto';

  @override
  String get accountabilityAddGoalPrimaryLabel => 'Título del objetivo';

  @override
  String get accountabilityAddOpenThreadPrimaryLabel =>
      'Título del hilo abierto';

  @override
  String get accountabilityAddGoalPrimaryHint =>
      'Construya una rutina matutina confiable';

  @override
  String get accountabilityAddGoalDetailHint =>
      'Despierta a las 5 a.m. y comienza el día limpiamente';

  @override
  String get accountabilityGoalAmountLabel => 'Cantidad necesaria';

  @override
  String get accountabilityGoalAmountHint =>
      '0 si este objetivo no necesita dinero';

  @override
  String get accountabilityMoneyPressureTitle => 'Cantidad total necesaria:';

  @override
  String get accountabilityAddOpenThreadPrimaryHint => 'Despierta a las 5 a.m.';

  @override
  String get accountabilityAddOpenThreadDetailHint =>
      'Despierto a las 5 a. m. y comienzo mi rutina matutina.';

  @override
  String get accountabilityGoalSaved => 'Gol salvado.';

  @override
  String get accountabilityOpenThreadSaved => 'Hilo abierto guardado.';

  @override
  String accountabilityOpenThreadMaxActive(int count) {
    return 'Puedes tener como máximo $count hilos abiertos activos. Cierra o pausa uno antes de agregar otro.';
  }

  @override
  String get accountabilityOpenThreadCompleted => 'Hilo abierto completado.';

  @override
  String get accountabilityMarkMissedTitle => '¿Mark falló?';

  @override
  String accountabilityMarkMissedBody(String title) {
    return '¿Marcar \"$title\" como perdido? Saldrá de su lista de objetivos activos.';
  }

  @override
  String get accountabilityArchiveOpenThreadTitle => '¿Borrar hilo abierto?';

  @override
  String accountabilityArchiveOpenThreadBody(String title) {
    return '¿Borrar \"$title\"? Saldrá de su lista de objetivos activos.';
  }

  @override
  String get accountabilityArchiveGoalTitle => '¿Borrar objetivo?';

  @override
  String accountabilityArchiveGoalBody(String title) {
    return '¿Borrar \"$title\"? Saldrá de su lista de objetivos activos.';
  }

  @override
  String get accountabilityOpenThreadMarkedMissed =>
      'Hilo abierto marcado como incumplido.';

  @override
  String get accountabilityOpenThreadArchived => 'Hilo abierto borrado.';

  @override
  String get accountabilityGoalArchived => 'Objetivo borrado.';

  @override
  String get accountabilityGoalUpdated => 'Objetivo actualizado.';

  @override
  String get accountabilityOpenThreadUpdated => 'Hilo abierto actualizado.';

  @override
  String get accountabilityUpdateFailed => 'Error al actualizar los objetivos.';

  @override
  String get accountabilityStatusOpen => 'Abierto';

  @override
  String get accountabilityStatusInProgress => 'En curso';

  @override
  String get accountabilityMarkAchieved => 'Marcar como logrado';

  @override
  String get accountabilityGoalAchieved => 'Bien — objetivo logrado.';

  @override
  String get accountabilityGoalReopened => 'Objetivo devuelto a activos.';

  @override
  String get accountabilitySectionsAchievedGoals => 'Logrados';

  @override
  String get accountabilitySectionsNoAchievedGoals =>
      'Todavía no terminaste ninguno.';

  @override
  String accountabilityAchievedOn(String date) {
    return 'Logrado el $date';
  }

  @override
  String get accountabilityReopenGoal => 'Devolver a activos';

  @override
  String get accountabilityStepsTitle => 'Pasos';

  @override
  String get accountabilityAddStep => 'Agregar paso';

  @override
  String get accountabilityAddStepHint => 'ej. Ahorrar \$500 para esto';

  @override
  String get accountabilityStepSaved => 'Paso agregado.';

  @override
  String get accountabilityStepUpdated => 'Paso actualizado.';

  @override
  String get accountabilityStepDeleted => 'Paso eliminado.';

  @override
  String accountabilityStepsDone(int done, int total) {
    return '$done de $total listos';
  }

  @override
  String get accountabilityDeleteStepTitle => '¿Eliminar paso?';

  @override
  String accountabilityDeleteStepBody(String title) {
    return '¿Eliminar \"$title\" de este objetivo?';
  }

  @override
  String get accountabilityDueDateRequired =>
      'Elige una fecha límite — un objetivo sin ella nunca se acerca.';

  @override
  String get accountabilitySetDueDate => 'Poner fecha límite';

  @override
  String get accountabilityNoDueDate => 'Sin fecha límite';

  @override
  String accountabilityDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Quedan $days días',
      one: 'Queda 1 día',
    );
    return '$_temp0';
  }

  @override
  String accountabilityDaysOver(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días de retraso',
      one: '1 día de retraso',
    );
    return '$_temp0';
  }

  @override
  String get accountabilityDueToday => 'Vence hoy';

  @override
  String conversationListEmptyFilteredTitle(String filter) {
    return 'No hay chats en $filter';
  }

  @override
  String get conversationListEmptyFilteredMessage =>
      'Borre el filtro de fechas o elija un rango más amplio.';

  @override
  String conversationListNoMatchesBody(String query, String suffix) {
    return 'No hay chats coincidentes \"$query\"$suffix';
  }

  @override
  String conversationListNoMatchesSuffixInFilter(String filter) {
    return 'en $filter';
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
    return '$count llamadas de IA';
  }

  @override
  String usageSummaryAiCallsThisMonth(int count) {
    return '$count Llamadas de IA este mes';
  }

  @override
  String get usageAdminTitle => 'Administración de uso';

  @override
  String get usageAdminSubtitle =>
      'Todos los usuarios · voz, chat, costo estimado';

  @override
  String get usageAdminOwnerSection => 'Dueño';

  @override
  String get usageAdminPlatformThisMonth => 'Plataforma este mes';

  @override
  String get usageAdminPlatformAllTime => 'Plataforma todo el tiempo';

  @override
  String usageAdminPlatformYear(int year) {
    return 'Plataforma $year';
  }

  @override
  String usageAdminPlatformMonth(String monthLabel) {
    return 'Plataforma $monthLabel';
  }

  @override
  String usageAdminPlatformDay(String dayLabel) {
    return 'Plataforma $dayLabel';
  }

  @override
  String get usageAdminFilterTitle => 'Periodo';

  @override
  String get usageAdminFilterAll => 'Todo';

  @override
  String get usageAdminFilterYear => 'Año';

  @override
  String get usageAdminFilterMonth => 'Mes';

  @override
  String get usageAdminFilterDay => 'Día';

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
    return '$registeredCount cuentas · $activeCount con uso · $voiceMinutes voz · $aiCalls llamadas AI';
  }

  @override
  String usageAdminActiveUsersSummary(
    int activeUserCount,
    String voiceMinutes,
    int aiCalls,
  ) {
    return '$activeUserCount usuarios activos · $voiceMinutes voz · $aiCalls llamadas AI';
  }

  @override
  String get usageAdminUsersSection => 'Usuarios';

  @override
  String get usageAdminNoRegisteredUsers => 'Aún no hay usuarios registrados.';

  @override
  String get usageAdminNoUsageInPeriod => 'No se registró uso en este periodo.';

  @override
  String get usageAdminNoUsageThisMonth =>
      'Aún no se ha registrado ningún uso este mes.';

  @override
  String usageAdminUserTileSummary(
    String voiceMinutes,
    int chatCalls,
    int voiceCalls,
  ) {
    return '$voiceMinutes voz · $chatCalls chat · $voiceCalls llamadas de voz';
  }

  @override
  String get usageAdminLoadingUserUsage => 'Cargando uso del usuario';

  @override
  String get usageAdminEstimatedCostThisMonth => 'Costo estimado este mes';

  @override
  String get usageAdminEstimatedCostPeriod => 'Costo estimado en el periodo';

  @override
  String get usageAdminUsageShape => 'Forma de uso';

  @override
  String get usageAdminDailyChartsCaption =>
      'Totales diarios del rango de fechas cargado';

  @override
  String get usageAdminRadarChartCaption =>
      'Totales del mes en curso (no diarios)';

  @override
  String get usageAdminRadarVoiceMin => 'Voz mínima';

  @override
  String get usageAdminRadarChatLlm => 'Chat LLM';

  @override
  String get usageAdminRadarVoiceLlm => 'Voz LLM';

  @override
  String get usageAdminRadarSttMin => 'STT min';

  @override
  String get usageAdminRadarTtsMin => 'TTS min';

  @override
  String get usageCostNotTracked => 'No rastreado';

  @override
  String get usageMinutesLessThanOne => '<1 minuto';

  @override
  String usageMinutesFormat(int minutes) {
    return '$minutes min';
  }

  @override
  String get usageAdminLoadFailed =>
      'No se pudo cargar el uso del propietario en este momento.';

  @override
  String get usageAdminUserLoadFailed =>
      'No se pudo cargar el historial de uso del usuario.';

  @override
  String get usageSummaryLoadFailed =>
      'No se pudo cargar el uso en este momento.';

  @override
  String get memoryErrorSignInAgain =>
      'Inicie sesión nuevamente para administrar la información guardada.';

  @override
  String get memoryErrorNoLongerAvailable =>
      'Esa memoria ya no está disponible.';

  @override
  String get memoryErrorEditValidation =>
      'Ese cambio de memoria no se pudo guardar. Verifique los campos e inténtelo nuevamente.';

  @override
  String get memoryErrorArchiveRefresh =>
      'Ese recuerdo no se pudo borrar. Actualiza la memoria y vuelve a intentarlo.';

  @override
  String get memoryErrorLoadRefresh =>
      'No se pudo cargar la información guardada. Actualiza e inténtalo de nuevo.';

  @override
  String get memoryErrorLoadConnection =>
      'No se pudo cargar la información guardada. Comprueba tu conexión y vuelve a intentarlo.';

  @override
  String get memoryErrorUpdateFailed =>
      'No se pudo actualizar esta memoria. Por favor inténtalo de nuevo.';

  @override
  String get memoryErrorArchiveFailed =>
      'No se pudo borrar esta memoria. Por favor inténtalo de nuevo.';

  @override
  String get memoryErrorCreateValidation =>
      'Esa memoria no se pudo guardar. Verifique los campos e inténtelo nuevamente.';

  @override
  String get memoryErrorCreateFailed =>
      'No se pudo guardar esta memoria. Por favor inténtalo de nuevo.';

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
  String get plaidLinkOpenFailed =>
      'No se pudo abrir la conexión bancaria en este navegador. Actualiza la página e inténtalo de nuevo.';

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
  String get chatPendingWriteHydrationFailed =>
      'No se pudo volver a cargar una confirmación de guardado pendiente. Desliza para actualizar o vuelve a abrir este chat.';

  @override
  String get chatConfirmWriteFailed =>
      'No se pudo confirmar el guardado. Toca Rever para intentarlo de nuevo.';

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
  String get voiceErrorMicPermanentlyDeniedWeb =>
      'El acceso al micrófono está bloqueado para este sitio. Abre la configuración del sitio en tu navegador, permite el micrófono para Clarity e inténtalo de nuevo.';

  @override
  String get voiceErrorMicRestricted =>
      'El acceso al micrófono está restringido en este dispositivo.';

  @override
  String get voiceErrorMicDenied =>
      'Se requiere permiso del micrófono para llamar a Rex. Toca Probar de nuevo para solicitar acceso, o actívalo en Ajustes de iOS > Privacidad y seguridad > Micrófono.';

  @override
  String get voiceErrorMicDeniedWeb =>
      'Se requiere permiso del micrófono para llamar a Rex. Haz clic en Probar de nuevo y permite el acceso al micrófono cuando tu navegador lo solicite.';

  @override
  String get voiceErrorMicInsecureContext =>
      'La voz necesita una conexión segura. Abre Clarity con https:// en lugar de http://.';

  @override
  String get voiceErrorMicBrowserSettings =>
      'Permite el micrófono para Clarity en la configuración del sitio de tu navegador (icono de candado en la barra de direcciones) y luego toca Probar de nuevo.';

  @override
  String get voiceErrorBackgroundMicRestart =>
      'El asistente no pudo reiniciar el micrófono en segundo plano. Abre el asistente para continuar.';
}
