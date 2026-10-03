import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.muratstudio.tablenote/home_widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "publish" else { result(FlutterMethodNotImplemented); return }
      guard let snapshot = call.arguments as? String,
            let data = snapshot.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["version"] as? Int == 1 else {
        result(FlutterError(code: "invalid_snapshot", message: "Expected widget snapshot", details: nil))
        return
      }
      let group = "group.com.muratstudio.tablenote"
      guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
            let defaults = UserDefaults(suiteName: group) else {
        result(FlutterError(code: "app_group_unavailable", message: "Enable the widget App Group", details: nil))
        return
      }
      defaults.set(snapshot, forKey: "snapshot")
      if #available(iOS 14.0, *) { WidgetCenter.shared.reloadTimelines(ofKind: "TableNoteSummary") }
      result(nil)
    }
  }
}
