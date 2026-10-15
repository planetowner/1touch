import Flutter
import UIKit

final class AvatarPickerHeaderFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AvatarPickerHeader(frame: frame, id: viewId, options: args as! [String: Any], messenger: messenger)
  }
}

private final class AvatarPickerHeader: NSObject, FlutterPlatformView {
  private let bar: AvatarNavigationBar
  private let titleAnchor = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
  private let close: UIBarButtonItem
  private let done: UIBarButtonItem
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, options: [String: Any], messenger: FlutterBinaryMessenger) {
    bar = AvatarNavigationBar(frame: frame)
    close = UIBarButtonItem(barButtonSystemItem: .close, target: nil, action: nil)
    done = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
    channel = FlutterMethodChannel(name: "onetouch/avatar_header/\(id)", binaryMessenger: messenger)
    super.init()
    close.target = self
    close.action = #selector(cancel)
    done.target = self
    done.action = #selector(confirm)
    if #available(iOS 26.0, *) { done.style = .prominent }
    let item = UINavigationItem()
    item.leftBarButtonItem = close
    item.rightBarButtonItem = done
    // 위치는 네이티브 제목 영역에서 얻고, 글꼴은 Flutter의 공통 토큰을 그대로 써요.
    item.titleView = titleAnchor
    bar.setItems([item], animated: false)
    bar.onLayout = { [weak self] in self?.reportLayout() }
    update(options)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update", let options = call.arguments as? [String: Any] {
        self?.update(options)
        result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }

  deinit { channel.setMethodCallHandler(nil) }
  func view() -> UIView { bar }
  @objc private func cancel() { channel.invokeMethod("cancel", arguments: nil) }
  @objc private func confirm() { channel.invokeMethod("done", arguments: nil) }

  private func update(_ options: [String: Any]) {
    bar.overrideUserInterfaceStyle = options["dark"] as? Bool == true ? .dark : .light
    close.accessibilityLabel = options["cancel"] as? String
    close.isEnabled = options["cancelEnabled"] as? Bool == true
    done.accessibilityLabel = options["done"] as? String
    done.isEnabled = options["doneEnabled"] as? Bool == true
    bar.setNeedsLayout()
    bar.layoutIfNeeded()
  }

  private func reportLayout() {
    guard titleAnchor.superview != nil else { return }
    let height = bar.sizeThatFits(CGSize(width: bar.bounds.width, height: .greatestFiniteMagnitude)).height
    channel.invokeMethod("layout", arguments: [
      "height": height,
      "titleCenterY": titleAnchor.convert(titleAnchor.bounds, to: bar).midY
    ])
  }
}

private final class AvatarNavigationBar: UINavigationBar {
  var onLayout: (() -> Void)?
  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
}
