import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    installNativeBridges()
    for context in connectionOptions.urlContexts {
      HomeScreenWidgetBridge.shared.handleOpenURL(context.url)
    }
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    installNativeBridges()
    if let url = URLContexts.first?.url,
       HomeScreenWidgetBridge.shared.handleOpenURL(url) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    installNativeBridges()
    if PlaidLinkBridge.shared.continueFrom(userActivity: userActivity) {
      return
    }
    super.scene(scene, continue: userActivity)
  }

  private func installNativeBridges() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    PlaidLinkBridge.shared.install(
      binaryMessenger: controller.binaryMessenger,
      rootViewController: controller
    )
    VoiceAudioBridge.shared.install(binaryMessenger: controller.binaryMessenger)
    HomeScreenWidgetBridge.shared.install(binaryMessenger: controller.binaryMessenger)
  }
}
