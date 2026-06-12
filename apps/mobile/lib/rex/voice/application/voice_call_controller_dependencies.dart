// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerDependencies on VoiceCallController {
  AudioCaptureService get _captureService {
    final existingService = _activeCaptureService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(audioCaptureServiceProvider);
    _activeCaptureService = service;
    return service;
  }

  StreamingAudioCaptureService get _streamingCaptureService {
    final existingService = _activeStreamingCaptureService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(streamingAudioCaptureServiceProvider);
    _activeStreamingCaptureService = service;
    return service;
  }

  AudioPlaybackService get _playbackService {
    final existingService = _activePlaybackService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(audioPlaybackServiceProvider);
    _activePlaybackService = service;
    return service;
  }

  SpeechToTextService get _interimSpeechToTextService {
    final existingService = _activeInterimSpeechToTextService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(speechToTextServiceProvider);
    _activeInterimSpeechToTextService = service;
    return service;
  }

  StreamingAudioPlaybackQueue get _streamingPlaybackQueue {
    final existingQueue = _activeStreamingPlaybackQueue;
    if (existingQueue != null) {
      return existingQueue;
    }
    final queue = ref.read(streamingAudioPlaybackQueueProvider);
    _activeStreamingPlaybackQueue = queue;
    return queue;
  }

  BargeInDetectionService get _bargeInDetectionService {
    final existingService = _activeBargeInDetectionService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(bargeInDetectionServiceProvider);
    _activeBargeInDetectionService = service;
    return service;
  }

  VoiceAudioSessionService get _audioSessionService {
    final existingService = _activeAudioSessionService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(voiceAudioSessionServiceProvider);
    _activeAudioSessionService = service;
    return service;
  }

  BackgroundVoiceService get _backgroundVoiceService {
    final existingService = _activeBackgroundVoiceService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(backgroundVoiceServiceProvider);
    _activeBackgroundVoiceService = service;
    return service;
  }

  NativeVoiceSessionService get _nativeVoiceSessionService {
    final existingService = _activeNativeVoiceSessionService;
    if (existingService != null) {
      return existingService;
    }
    final service = ref.read(nativeVoiceSessionServiceProvider);
    _activeNativeVoiceSessionService = service;
    return service;
  }
}
