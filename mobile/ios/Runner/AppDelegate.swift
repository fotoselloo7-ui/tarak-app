import Flutter
import UIKit

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
    AppIconChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// "Uygulama ikonu" seçimi: aynı Tarak işareti, farklı arka plan rengi. Alternatif simgeler
/// `Assets.xcassets/AppIcon-<Id>.appiconset` içinde (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`);
/// varsayılan simge (`AppIcon`) `alternateIconName == nil` demektir. iOS değişimde kendi bilgi penceresini gösterir.
enum AppIconChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.tarak.mobile/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      let defaultId = args?["default"] as? String ?? "altin"
      switch call.method {
      case "isSupported":
        result(UIApplication.shared.supportsAlternateIcons)
      case "current":
        if let name = UIApplication.shared.alternateIconName, name.hasPrefix("AppIcon-") {
          result(String(name.dropFirst("AppIcon-".count)).lowercased())
        } else {
          result(defaultId)
        }
      case "change":
        guard let id = args?["id"] as? String, !id.isEmpty else {
          result(FlutterError(code: "invalid_icon", message: "Bilinmeyen ikon", details: nil))
          return
        }
        let name: String? = id == defaultId ? nil : "AppIcon-" + id.prefix(1).uppercased() + id.dropFirst()
        UIApplication.shared.setAlternateIconName(name) { error in
          if let error = error {
            result(FlutterError(code: "icon_failed", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
