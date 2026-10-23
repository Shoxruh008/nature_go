import UIKit
import Flutter
import YandexMapsMobile

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Kalit gitda saqlanmaydi: ios/Flutter/Secrets.xcconfig -> Info.plist
    if let key = Bundle.main.object(forInfoDictionaryKey: "YandexMapKitApiKey") as? String,
       !key.isEmpty {
      YMKMapKit.setApiKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}