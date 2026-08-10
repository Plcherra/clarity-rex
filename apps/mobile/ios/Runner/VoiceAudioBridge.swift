import Flutter
import UIKit
import AVFoundation

/// Native AVAudioSession bridge for Clarity voice calls.
/// Category playAndRecord + mode voiceChat (AEC) and background arming.
final class VoiceAudioBridge {
  static let shared = VoiceAudioBridge()

  private var isInstalled = false

  private init() {}

  func install(binaryMessenger: FlutterBinaryMessenger) {
    guard !isInstalled else {
      return
    }
    isInstalled = true

    let audioChannel = FlutterMethodChannel(
      name: "clarity/voice_audio",
      binaryMessenger: binaryMessenger
    )
    audioChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "preferLoudSpeaker":
        self?.preferLoudSpeaker(result: result)
      case "openAppSettings":
        self?.openAppSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let backgroundChannel = FlutterMethodChannel(
      name: "rex/voice_background",
      binaryMessenger: binaryMessenger
    )
    backgroundChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "start":
        self?.armVoiceChatSession(result: result)
      case "stop":
        // Dart deactivates the session on endCall.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func armVoiceChatSession(result: FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]
      )
      try session.setActive(true, options: [])
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "VOICE_BACKGROUND_ARM_FAILED",
          message: "Could not arm the voice audio session for background.",
          details: error.localizedDescription
        )
      )
    }
  }

  private func preferLoudSpeaker(result: FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]
      )
      try session.setActive(true)
      if hasExternalAudioRoute(session.currentRoute) {
        try session.overrideOutputAudioPort(.none)
      } else {
        try session.overrideOutputAudioPort(.speaker)
      }
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "VOICE_AUDIO_ROUTE_FAILED",
          message: "Could not prefer the loud speaker output.",
          details: error.localizedDescription
        )
      )
    }
  }

  private func hasExternalAudioRoute(_ route: AVAudioSessionRouteDescription) -> Bool {
    route.outputs.contains { output in
      switch output.portType {
      case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones, .airPlay:
        return true
      default:
        return false
      }
    }
  }

  private func openAppSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(
        FlutterError(
          code: "APP_SETTINGS_URL_UNAVAILABLE",
          message: "Could not build the app settings URL.",
          details: nil
        )
      )
      return
    }
    UIApplication.shared.open(url, options: [:]) { _ in
      result(nil)
    }
  }
}
