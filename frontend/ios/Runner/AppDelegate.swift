import Flutter
import UIKit
import UserNotifications
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var attachmentChannel: FlutterMethodChannel?
  private var videoEncoderBridge: VideoEncoderBridge?
  private var mediaPickerBridge: MediaPickerBridge?
  private var pendingAttachmentChoice: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    engineBridge.applicationRegistrar.register(
      AvatarPickerHeaderFactory(messenger: engineBridge.applicationRegistrar.messenger()),
      withId: "onetouch/avatar_header")
    videoEncoderBridge = VideoEncoderBridge(messenger: engineBridge.applicationRegistrar.messenger())
    mediaPickerBridge = MediaPickerBridge(
      messenger: engineBridge.applicationRegistrar.messenger(),
      presentingController: { [weak self] in self?.topController() }
    )
    attachmentChannel = FlutterMethodChannel(
      name: "onetouch/community_attachment",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    attachmentChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleAttachmentCall(call, result: result)
    }
  }

  private func handleAttachmentCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
      return
    }
    switch call.method {
    case "choose":
      guard let controller = topController() else {
        result(FlutterError(code: "no_controller", message: nil, details: nil))
        return
      }
      guard pendingAttachmentChoice == nil else {
        result(FlutterError(code: "choice_open", message: nil, details: nil))
        return
      }
      pendingAttachmentChoice = result
      let sheet = AttachmentActionSheetController(
        saveTitle: args["save"] as? String ?? "Save",
        shareTitle: args["share"] as? String ?? "Share"
      ) { [weak self] action in
        self?.completeAttachmentChoice(action)
      }
      controller.present(sheet, animated: false)
    case "save":
      guard let path = args["path"] as? String,
            let isVideo = args["isVideo"] as? Bool else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
        return
      }
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async {
            result(FlutterError(code: "access_denied", message: nil, details: nil))
          }
          return
        }
        PHPhotoLibrary.shared().performChanges {
          if isVideo {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
          } else {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
          }
        } completionHandler: { saved, error in
          DispatchQueue.main.async {
            if saved {
              result(nil)
            } else {
              result(FlutterError(code: "save_failed", message: error?.localizedDescription, details: nil))
            }
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func completeAttachmentChoice(_ action: String?) {
    let reply = pendingAttachmentChoice
    pendingAttachmentChoice = nil
    reply?(action)
  }

  private func topController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?.rootViewController
    var top = root
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

private final class AttachmentActionSheetController: UIViewController {
  private let saveTitle: String
  private let shareTitle: String
  private let onChoice: (String?) -> Void
  private let dimView = UIView()
  private let panel = UIView()
  private var isClosing = false

  init(saveTitle: String, shareTitle: String, onChoice: @escaping (String?) -> Void) {
    self.saveTitle = saveTitle
    self.shareTitle = shareTitle
    self.onChoice = onChoice
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear

    dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
    dimView.translatesAutoresizingMaskIntoConstraints = false
    dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeWithoutChoice)))
    view.addSubview(dimView)

    panel.backgroundColor = .secondarySystemBackground
    panel.layer.cornerRadius = 20
    panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    panel.translatesAutoresizingMaskIntoConstraints = false
    panel.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragPanel(_:))))
    view.addSubview(panel)

    let actions = UIStackView(arrangedSubviews: [
      actionButton(saveTitle, symbol: "square.and.arrow.down", selector: #selector(saveTapped)),
      actionButton(shareTitle, symbol: "square.and.arrow.up", selector: #selector(shareTapped))
    ])
    actions.axis = .vertical
    actions.spacing = 8
    actions.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(actions)

    NSLayoutConstraint.activate([
      dimView.topAnchor.constraint(equalTo: view.topAnchor),
      dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      actions.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
      actions.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
      actions.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
      actions.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -16)
    ])
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dimView.alpha = 0
    panel.transform = CGAffineTransform(translationX: 0, y: 300)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
      self.dimView.alpha = 1
      self.panel.transform = .identity
    }
  }

  private func actionButton(_ title: String, symbol: String, selector: Selector) -> UIButton {
    var configuration = UIButton.Configuration.filled()
    configuration.title = title
    configuration.image = UIImage(systemName: symbol)
    configuration.imagePadding = 12
    configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    configuration.baseForegroundColor = .label
    configuration.baseBackgroundColor = .tertiarySystemBackground
    let button = UIButton(configuration: configuration)
    button.contentHorizontalAlignment = .leading
    button.heightAnchor.constraint(equalToConstant: 52).isActive = true
    button.addTarget(self, action: selector, for: .touchUpInside)
    return button
  }

  @objc private func saveTapped() { close(with: "save") }
  @objc private func shareTapped() { close(with: "share") }
  @objc private func closeWithoutChoice() { close(with: nil) }

  @objc private func dragPanel(_ gesture: UIPanGestureRecognizer) {
    if isClosing { return }
    let distance = max(0, gesture.translation(in: view).y)
    switch gesture.state {
    case .changed:
      panel.transform = CGAffineTransform(translationX: 0, y: distance)
      dimView.alpha = max(0, 1 - distance / 300)
    case .ended, .cancelled:
      if distance > 70 || gesture.velocity(in: view).y > 700 {
        close(with: nil)
      } else {
        UIView.animate(withDuration: 0.2) {
          self.panel.transform = .identity
          self.dimView.alpha = 1
        }
      }
    default:
      break
    }
  }

  private func close(with action: String?) {
    if isClosing { return }
    isClosing = true
    UIView.animate(withDuration: 0.2, animations: {
      self.dimView.alpha = 0
      self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height)
    }) { _ in
      self.dismiss(animated: false) { self.onChoice(action) }
    }
  }
}
