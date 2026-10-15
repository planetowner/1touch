import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class MediaPickerBridge: NSObject, PHPickerViewControllerDelegate,
  UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private let presentingController: () -> UIViewController?
  private var pendingResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger, presentingController: @escaping () -> UIViewController?) {
    channel = FlutterMethodChannel(name: "onetouch/media_picker", binaryMessenger: messenger)
    self.presentingController = presentingController
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pick" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "picker_open", message: nil, details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let maximum = args["maxAssets"] as? Int, maximum > 0,
          let imagesOnly = args["imagesOnly"] as? Bool else {
      result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
      return
    }
    guard let controller = presentingController() else {
      result(FlutterError(code: "no_controller", message: nil, details: nil))
      return
    }
    // 보관함 권한 없이 선택한 파일만 받아요. 게시글은 사용자가 고른 순서를 유지해요.
    var configuration = PHPickerConfiguration()
    configuration.filter = imagesOnly ? .images : .any(of: [.images, .videos])
    configuration.selectionLimit = maximum
    configuration.selection = maximum == 1 ? .default : .ordered
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    picker.presentationController?.delegate = self
    pendingResult = result
    controller.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) {
      if results.isEmpty {
        self.complete([])
        return
      }
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("picked-\(UUID().uuidString)", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.export(results, directory: directory, files: [])
      } catch {
        self.complete(FlutterError(code: "picker_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    complete([])
  }

  private func export(_ results: [PHPickerResult], directory: URL, files: [[String: String]]) {
    guard files.count < results.count else {
      complete(files)
      return
    }
    let provider = results[files.count].itemProvider
    let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
    let type = isVideo ? UTType.movie : UTType.image
    // 제공자가 임시 파일을 지우기 전에 복사하고, 한 개씩 내보내 선택 순서를 유지해요.
    provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
      do {
        if let error { throw error }
        guard let url else { throw CocoaError(.fileReadNoSuchFile) }
        let file = try Self.copyMedia(url, isVideo: isVideo, directory: directory, index: files.count)
        self.export(results, directory: directory, files: files + [file])
      } catch {
        try? FileManager.default.removeItem(at: directory)
        self.complete(FlutterError(code: "picker_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  static func copyMedia(_ source: URL, isVideo: Bool, directory: URL, index: Int) throws -> [String: String] {
    var mimeType: String
    let target: URL
    if isVideo {
      mimeType = UTType(filenameExtension: source.pathExtension)?.preferredMIMEType ?? "video/*"
      target = directory.appendingPathComponent("\(index).\(source.pathExtension)")
      try FileManager.default.copyItem(at: source, to: target)
    } else {
      guard let image = CGImageSourceCreateWithURL(source as CFURL, nil),
            let identifier = CGImageSourceGetType(image),
            let type = UTType(identifier as String) else {
        throw CocoaError(.fileReadCorruptFile)
      }
      mimeType = type.preferredMIMEType ?? ""
      if ["image/jpeg", "image/png", "image/gif", "image/webp"].contains(mimeType) {
        target = directory.appendingPathComponent("\(index).\(source.pathExtension)")
        try FileManager.default.copyItem(at: source, to: target)
      } else {
        // 서버가 받지 않는 HEIC 등은 크기와 회전 정보를 유지한 JPEG로 내보내요.
        target = directory.appendingPathComponent("\(index).jpg")
        guard let destination = CGImageDestinationCreateWithURL(
          target as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImageFromSource(destination, image, 0,
          [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        mimeType = "image/jpeg"
      }
    }
    return ["path": target.path, "mimeType": mimeType]
  }

  private func complete(_ value: Any) {
    DispatchQueue.main.async {
      let result = self.pendingResult
      self.pendingResult = nil
      result?(value)
    }
  }
}
