import AppTrackingTransparency
import Flutter
import UIKit
import UserMessagingPlatform

final class TrackingAuthorizationBridge {
  private let channel: FlutterMethodChannel
  private var activationObserver: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "onetouch/tracking_authorization", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, reply in
      guard call.method == "prepareForAds" else {
        reply(FlutterMethodNotImplemented)
        return
      }
      self?.prepareForAds(reply)
    }
  }

  deinit {
    if let observer = activationObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  static func shouldRequestAuthorization(
    defaults: UserDefaults, consentNotRequired: Bool
  ) -> Bool {
    let gdprApplies = defaults.object(forKey: "IABTCF_gdprApplies") as? Int
    if gdprApplies == 0 { return true }
    guard gdprApplies == 1 else { return consentNotRequired }

    // UMP는 거절 후에도 제한된 광고를 허용할 수 있어 canRequestAds만으로 판단하지 않아요.
    // 기기 정보 접근(목적 1)과 Google 광고 제품(업체 755)에 동의한 경우에만 ATT를 물어요.
    // 실제 광고의 처리 목적·제한은 SDK가 UMP의 전체 TC 문자열을 읽어 적용해요.
    // https://developers.google.com/admob/ios/privacy/gdpr
    let purposes = defaults.string(forKey: "IABTCF_PurposeConsents")
    let vendors = defaults.string(forKey: "IABTCF_VendorConsents")
    return purposes?.first == "1" && vendors?.dropFirst(754).first == "1"
  }

  private func prepareForAds(_ reply: @escaping FlutterResult) {
    guard Self.shouldRequestAuthorization(
      defaults: .standard,
      consentNotRequired: ConsentInformation.shared.consentStatus == .notRequired
    ) else {
      // Google 동의창에서 거절했으면 ATT를 건너뛰고 UMP가 허용한 광고만 요청해요.
      reply(true)
      return
    }

    let status = ATTrackingManager.trackingAuthorizationStatus
    guard status == .notDetermined else {
      // 이미 선택했거나 기기에서 추적이 제한된 경우에는 다시 묻지 않아요.
      reply(Self.isResolved(status))
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
        self.prepareForAds(reply)
      }
      return
    }

    ATTrackingManager.requestTrackingAuthorization { status in
      DispatchQueue.main.async {
        reply(Self.isResolved(status))
      }
    }
  }

  private static func isResolved(_ status: ATTrackingManager.AuthorizationStatus) -> Bool {
    switch status {
    case .authorized, .denied, .restricted:
      return true
    case .notDetermined:
      return false
    @unknown default:
      return false
    }
  }
}
