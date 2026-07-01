// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerL10n on VoiceCallController {
  AppLocalizations get voiceL10n {
    try {
      return lookupForLocale(ref.read(localeControllerProvider).locale);
    } on Object {
      return lookupEnglishLocalizationsForTests();
    }
  }

  void failL10n(String Function(AppLocalizations l10n) message) {
    fail(message(voiceL10n));
  }

  void failVoiceApi(Object error) {
    fail(friendlyVoiceApiError(voiceL10n, error));
  }

  String localizedVoiceFailure(String? reason) {
    if (reason == null || reason.trim().isEmpty) {
      return voiceL10n.voiceFailurePausedDefault;
    }
    return reason;
  }

  String permissionMessage(MicrophonePermissionDecision decision) {
    if (decision == MicrophonePermissionDecision.insecureContext) {
      return voiceL10n.voiceErrorMicInsecureContext;
    }

    if (kIsWeb) {
      return switch (decision) {
        MicrophonePermissionDecision.permanentlyDenied =>
          voiceL10n.voiceErrorMicPermanentlyDeniedWeb,
        MicrophonePermissionDecision.restricted =>
          voiceL10n.voiceErrorMicRestricted,
        MicrophonePermissionDecision.denied => voiceL10n.voiceErrorMicDeniedWeb,
        MicrophonePermissionDecision.granted => '',
        MicrophonePermissionDecision.insecureContext =>
          voiceL10n.voiceErrorMicInsecureContext,
      };
    }

    return switch (decision) {
      MicrophonePermissionDecision.permanentlyDenied =>
        voiceL10n.voiceErrorMicPermanentlyDenied,
      MicrophonePermissionDecision.restricted =>
        voiceL10n.voiceErrorMicRestricted,
      MicrophonePermissionDecision.denied => voiceL10n.voiceErrorMicDenied,
      MicrophonePermissionDecision.granted => '',
      MicrophonePermissionDecision.insecureContext =>
        voiceL10n.voiceErrorMicInsecureContext,
    };
  }
}
