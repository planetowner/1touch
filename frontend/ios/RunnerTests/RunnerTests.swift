import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testATTRequiresDeviceStorageAndGoogleConsentWhenGDPRapplies() throws {
    let suite = "onetouch.att-test.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(1, forKey: "IABTCF_gdprApplies")
    let googleConsent = String(repeating: "0", count: 754) + "1"
    let cases: [(String?, String?, Bool)] = [
      (nil, nil, false),
      ("0000000000", googleConsent, false),
      ("1000000000", nil, false),
      ("1000000000", String(repeating: "1", count: 754) + "0", false),
      ("1000000000", "1", false),
      ("1000000000", googleConsent, true),
      ("1111111111", googleConsent, true),
    ]
    for (purposes, vendors, expected) in cases {
      defaults.set(purposes, forKey: "IABTCF_PurposeConsents")
      defaults.set(vendors, forKey: "IABTCF_VendorConsents")
      XCTAssertEqual(TrackingAuthorizationBridge.shouldRequestAuthorization(
        defaults: defaults, consentNotRequired: false), expected)
    }
  }

  func testATTOutsideGDPRAndUnknownConsent() throws {
    let suite = "onetouch.att-test.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    XCTAssertFalse(TrackingAuthorizationBridge.shouldRequestAuthorization(
      defaults: defaults, consentNotRequired: false))
    XCTAssertTrue(TrackingAuthorizationBridge.shouldRequestAuthorization(
      defaults: defaults, consentNotRequired: true))
    defaults.set(0, forKey: "IABTCF_gdprApplies")
    XCTAssertTrue(TrackingAuthorizationBridge.shouldRequestAuthorization(
      defaults: defaults, consentNotRequired: false))
  }

  func testPickerPreservesPNGBytesAndVideoType() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let png = directory.appendingPathComponent("source.png")
    let bytes = try XCTUnwrap(makeImage().pngData())
    try bytes.write(to: png)

    let photo = try MediaPickerBridge.copyMedia(png, isVideo: false, directory: directory, index: 0)
    XCTAssertEqual(photo["mimeType"], "image/png")
    XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: XCTUnwrap(photo["path"]))), bytes)

    let movie = directory.appendingPathComponent("source.mov")
    let videoBytes = Data([1, 2, 3])
    try videoBytes.write(to: movie)
    let video = try MediaPickerBridge.copyMedia(movie, isVideo: true, directory: directory, index: 1)
    XCTAssertEqual(video["mimeType"], "video/quicktime")
    XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: XCTUnwrap(video["path"]))), videoBytes)
  }

  func testPickerConvertsHEICWithoutResizingOrLosingOrientation() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let heic = directory.appendingPathComponent("source.heic")
    let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
      heic as CFURL, UTType.heic.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(makeImage().cgImage),
      [kCGImagePropertyOrientation: 6] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))

    let photo = try MediaPickerBridge.copyMedia(heic, isVideo: false, directory: directory, index: 0)
    XCTAssertEqual(photo["mimeType"], "image/jpeg")
    let output = URL(fileURLWithPath: try XCTUnwrap(photo["path"]))
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
    XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 90)
    XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 160)
    XCTAssertEqual(properties[kCGImagePropertyOrientation] as? Int, 6)
  }

  private func makeDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func makeImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 90, height: 160), format: format).image { context in
      UIColor.blue.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 90, height: 160))
    }
  }

}
