import AppTrackingTransparency
import Flutter
import UIKit

final class TrackingAuthorizationBridge {
  private let channel: FlutterMethodChannel
  private var activationObserver: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "onetouch/tracking_authorization", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard call.method == "requestAuthorization" else {
        reply(FlutterMethodNotImplemented)
        return
      }
      self?.requestAuthorization(reply)
    }
  }

  deinit {
    if let observer = activationObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func requestAuthorization(_ reply: @escaping FlutterResult) {
    let status = ATTrackingManager.trackingAuthorizationStatus
    guard status == .notDetermined else {
      // 이미 선택했거나 기기에서 추적이 제한된 경우에는 다시 묻지 않아요.
      reply(status.rawValue)
      return
    }

    // 앱이 비활성 상태면 ATT 창이 뜨지 않으므로 실제로 활성화될 때까지 기다려요.
    guard UIApplication.shared.applicationState == .active else {
      activationObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        if let observer = self.activationObserver {
          NotificationCenter.default.removeObserver(observer)
          self.activationObserver = nil
        }
        self.requestAuthorization(reply)
      }
      return
    }

    ATTrackingManager.requestTrackingAuthorization { status in
      DispatchQueue.main.async {
        reply(status.rawValue)
      }
    }
  }
}
