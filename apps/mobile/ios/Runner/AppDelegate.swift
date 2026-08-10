import Flutter
import UIKit
import LinkKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      VoiceAudioBridge.shared.install(binaryMessenger: controller.binaryMessenger)
      PlaidLinkBridge.shared.install(
        binaryMessenger: controller.binaryMessenger,
        rootViewController: controller
      )
    }
    return didFinish
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if PlaidLinkBridge.shared.continueFrom(userActivity: userActivity) {
      return true
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

final class PlaidLinkBridge {
  static let shared = PlaidLinkBridge()

  private var channel: FlutterMethodChannel?
  private weak var rootViewController: FlutterViewController?
  private var session: PlaidLinkSession?
  private var pendingResult: FlutterResult?
  private var isInstalled = false

  private init() {}

  func install(
    binaryMessenger: FlutterBinaryMessenger,
    rootViewController: FlutterViewController
  ) {
    self.rootViewController = rootViewController
    if isInstalled {
      return
    }
    let channel = FlutterMethodChannel(
      name: "clarity/plaid_link",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.open(call: call, result: result)
    }
    self.channel = channel
    isInstalled = true
  }

  func continueFrom(userActivity: NSUserActivity) -> Bool {
    // LinkKit handles OAuth continuation internally for Link token sessions.
    false
  }

  private func open(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let work = {
      guard self.pendingResult == nil else {
        result(
          FlutterError(
            code: "PLAID_LINK_BUSY",
            message: "A bank connection is already in progress.",
            details: nil
          )
        )
        return
      }

      guard let arguments = call.arguments as? [String: Any],
            let linkToken = arguments["linkToken"] as? String,
            !linkToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(
          FlutterError(
            code: "PLAID_LINK_TOKEN_MISSING",
            message: "Could not open bank connection without a Link token.",
            details: nil
          )
        )
        return
      }

      guard let presenter = self.topViewController(from: self.rootViewController) else {
        result(
          FlutterError(
            code: "PLAID_LINK_PRESENTER_MISSING",
            message: "Could not find a screen to present bank connection.",
            details: nil
          )
        )
        return
      }

      self.pendingResult = result

      let configuration = LinkTokenConfiguration(
        token: linkToken,
        onSuccess: { [weak self] success in
          self?.complete(success: success)
        },
        onExit: { [weak self] exit in
          self?.complete(exit: exit)
        },
        onEvent: { event in
          let viewName = event.metadata.viewName?.description ?? "unknown"
          let requestId = event.metadata.requestID ?? "none"
          print(
            "PlaidLink native event=\(event.eventName.description) view=\(viewName) request_id=\(requestId)"
          )
        },
        onLoad: {
          print("PlaidLink native loaded")
        }
      )

      do {
        let session = try Plaid.createPlaidLinkSession(configuration: configuration)
        self.session = session
        session.open(using: .viewController(presenter))
      } catch {
        self.pendingResult = nil
        result(
          FlutterError(
            code: "PLAID_LINK_CREATE_FAILED",
            message: "Could not open bank connection.",
            details: error.localizedDescription
          )
        )
      }
    }

    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }

  private func complete(success: LinkSuccess) {
    let payload: [String: Any] = [
      "type": "success",
      "publicToken": success.publicToken,
      "institutionId": success.metadata.institution.id,
      "institutionName": success.metadata.institution.name,
      "accountCount": success.metadata.accounts.count
    ]
    finish(payload)
  }

  private func complete(exit: LinkExit) {
    var payload: [String: Any] = [
      "type": "exit"
    ]
    if let status = exit.metadata.status?.description {
      payload["linkStatus"] = status
    }
    if let requestId = exit.metadata.requestID {
      payload["requestId"] = requestId
    }
    if let error = exit.error {
      payload["errorCode"] = error.errorCode.description
      payload["errorType"] = "plaid_link_exit"
      payload["errorMessage"] = error.displayMessage ?? error.errorMessage
    }
    finish(payload)
  }

  private func finish(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      let result = self.pendingResult
      self.pendingResult = nil
      self.session = nil
      result?(payload)
    }
  }

  private func topViewController(from root: UIViewController?) -> UIViewController? {
    if let navigation = root as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(from: presented)
    }
    return root
  }
}
