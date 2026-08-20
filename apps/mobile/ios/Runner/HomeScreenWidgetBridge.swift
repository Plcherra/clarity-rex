import Flutter
import Foundation
import WidgetKit

final class HomeScreenWidgetBridge {
  static let shared = HomeScreenWidgetBridge()

  static let channelName = "clarity/home_screen_widget"
  static let appGroupId = "group.app.goclarity.clarity"
  static let kind = "ClarityHomeWidget"
  static let openScheme = "io.goclarity.clarity"
  static let openHost = "overview"

  private static let storedKeys = [
    "clarity.widget.cashLabel",
    "clarity.widget.cashValue",
    "clarity.widget.leftLabel",
    "clarity.widget.leftValue",
    "clarity.widget.leftNegative",
    "clarity.widget.hasAccounts",
    "clarity.widget.emptyMessage",
  ]

  private var channel: FlutterMethodChannel?
  private var isInstalled = false
  private var pendingHost: String?

  private init() {}

  func install(binaryMessenger: FlutterBinaryMessenger) {
    if isInstalled {
      return
    }
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
    isInstalled = true
  }

  @discardableResult
  func handleOpenURL(_ url: URL) -> Bool {
    guard url.scheme == Self.openScheme, url.host == Self.openHost else {
      return false
    }
    if let channel {
      channel.invokeMethod("opened", arguments: Self.openHost)
    } else {
      pendingHost = Self.openHost
    }
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "publish":
      guard let payload = call.arguments as? [String: String] else {
        result(
          FlutterError(
            code: "HOME_WIDGET_PAYLOAD",
            message: "Widget payload must be string keys and values.",
            details: nil
          )
        )
        return
      }
      write(payload)
      WidgetCenter.shared.reloadTimelines(ofKind: Self.kind)
      result(nil)
    case "clear":
      clearStoredFields()
      WidgetCenter.shared.reloadTimelines(ofKind: Self.kind)
      result(nil)
    case "consumePending":
      let host = pendingHost
      pendingHost = nil
      result(host)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func write(_ payload: [String: String]) {
    guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
      return
    }
    for key in Self.storedKeys {
      if let value = payload[key], !value.isEmpty {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  private func clearStoredFields() {
    guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
      return
    }
    for key in Self.storedKeys {
      defaults.removeObject(forKey: key)
    }
  }
}
