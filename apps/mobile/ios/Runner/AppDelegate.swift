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
      PlaidOAuthLinkStream.shared.install(binaryMessenger: controller.binaryMessenger)
    }
    return didFinish
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    PlaidOAuthLinkStream.shared.emit(userActivity: userActivity)
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
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

final class PlaidOAuthLinkStream: NSObject, FlutterStreamHandler {
  static let shared = PlaidOAuthLinkStream()

  private var eventSink: FlutterEventSink?
  private var pendingLinks: [String] = []

  func install(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterEventChannel(
      name: "clarity/plaid_oauth_links",
      binaryMessenger: binaryMessenger
    )
    channel.setStreamHandler(self)
  }

  func emit(userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL
    else {
      return
    }
    emit(url: url)
  }

  private func emit(url: URL) {
    let value = url.absoluteString
    DispatchQueue.main.async {
      if let sink = self.eventSink {
        sink(value)
      } else {
        self.pendingLinks.append(value)
      }
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    pendingLinks.forEach { events($0) }
    pendingLinks.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
