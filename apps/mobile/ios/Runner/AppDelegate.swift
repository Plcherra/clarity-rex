import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      installVoiceAudioChannel(binaryMessenger: controller.binaryMessenger)
    }
    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func installVoiceAudioChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "clarity/voice_audio",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "preferLoudSpeaker":
        self.preferLoudSpeaker(result: result)
      case "openAppSettings":
        self.openAppSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func preferLoudSpeaker(result: FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .spokenAudio,
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
