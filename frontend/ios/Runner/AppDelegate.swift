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

    let regionChannel = FlutterMethodChannel(
      name: "com.onetouch.football/device_region",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    regionChannel.setMethodCallHandler { call, result in
      guard call.method == "getRegionCode" else {
        result(FlutterMethodNotImplemented)
        return
      }

      // 로그인 추천은 화면 언어 대신 사용자가 설정한 지역을 따라요.
      if #available(iOS 16, *) {
        result(Locale.current.region?.identifier)
      } else {
        result(Locale.current.regionCode)
      }
    }
  }
}
