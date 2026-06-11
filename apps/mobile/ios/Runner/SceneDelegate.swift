import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    PlaidOAuthLinkStream.shared.emit(userActivity: userActivity)
    super.scene(scene, continue: userActivity)
  }
}
