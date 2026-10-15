import Flutter
import UIKit

final class NativeActionSheetBridge: NSObject, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private let presentingController: () -> UIViewController?
  private var pendingResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger, presentingController: @escaping () -> UIViewController?) {
    channel = FlutterMethodChannel(name: "onetouch/action_sheet", binaryMessenger: messenger)
    self.presentingController = presentingController
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "show" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "choice_open", message: nil, details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let actions = args["actions"] as? [[String: Any]],
          let cancel = args["cancel"] as? String else {
      result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
      return
    }
    guard let controller = presentingController() else {
      result(FlutterError(code: "no_controller", message: nil, details: nil))
      return
    }

    let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    sheet.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    let finish: (String?) -> Void = { [weak self] choice in
      // 메뉴 닫기는 UIKit에 맡기고, 기존 화면에는 선택 결과만 전달해요.
      self?.complete(choice)
    }
    for action in actions {
      sheet.addAction(UIAlertAction(
        title: action["title"] as? String,
        style: action["destructive"] as? Bool == true ? .destructive : .default
      ) { _ in finish(action["id"] as? String) })
    }
    sheet.addAction(UIAlertAction(title: cancel, style: .cancel) { _ in finish(nil) })
    sheet.presentationController?.delegate = self
    pendingResult = result
    controller.present(sheet, animated: true)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    complete(nil)
  }

  private func complete(_ choice: String?) {
    let result = pendingResult
    pendingResult = nil
    result?(choice)
  }
}
