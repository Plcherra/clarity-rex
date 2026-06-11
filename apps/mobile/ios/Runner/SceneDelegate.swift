import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    installPlaidLinkBridge()
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    installPlaidLinkBridge()
    if PlaidLinkBridge.shared.continueFrom(userActivity: userActivity) {
      return
    }
    super.scene(scene, continue: userActivity)
  }

  private func installPlaidLinkBridge() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    PlaidLinkBridge.shared.install(
      binaryMessenger: controller.binaryMessenger,
      rootViewController: controller
    )
  }
}
