import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    installPlaidOAuthLinkStream()
    connectionOptions.userActivities.forEach {
      PlaidOAuthLinkStream.shared.emit(userActivity: $0)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    installPlaidOAuthLinkStream()
    PlaidOAuthLinkStream.shared.emit(userActivity: userActivity)
    super.scene(scene, continue: userActivity)
  }

  private func installPlaidOAuthLinkStream() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    PlaidOAuthLinkStream.shared.install(binaryMessenger: controller.binaryMessenger)
  }
}
