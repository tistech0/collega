import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      // Partie B : les PDF gardés sur le téléphone ne partent pas dans la sauvegarde iCloud.
      FlutterMethodChannel(name: "collega/backup", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "excludeFromBackup",
                let args = call.arguments as? [String: Any],
                let path = args["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
          }
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          do {
            try url.setResourceValues(values)
            result(nil)
          } catch {
            result(FlutterError(code: "BACKUP_EXCLUDE_FAILED", message: error.localizedDescription, details: nil))
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
