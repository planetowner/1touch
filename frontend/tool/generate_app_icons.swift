// Run from the frontend directory: swift -module-cache-path /private/tmp/onetouch-swift-cache tool/generate_app_icons.swift
// Source artwork is the existing vector wordmark at assets/app_logo.svg.
import AppKit
import Foundation

let sourceURL = URL(fileURLWithPath: "assets/app_logo.svg")
guard let wordmark = NSImage(contentsOf: sourceURL) else {
  fatalError("Unable to load assets/app_logo.svg")
}

let background = NSColor(srgbRed: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1)

func render(size: Int, visibleWidthFraction: CGFloat, transparent: Bool = false) -> Data {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create \(size)px icon")
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.imageInterpolation = .high
  let side = CGFloat(size)
  if (!transparent) {
    background.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
  }

  // The existing 128x26 SVG has its visible paths at x=4...124 and
  // approximately y=0...17. Scale and center the visible artwork, rather
  // than the SVG's extra whitespace and drop-shadow canvas.
  let scale = side * visibleWidthFraction / 120
  wordmark.draw(
    in: NSRect(
      x: side / 2 - 64 * scale,
      y: side / 2 - 13 * scale - 4 * scale,
      width: 128 * scale,
      height: 26 * scale
    ),
    from: NSRect(origin: .zero, size: wordmark.size),
    operation: .sourceOver,
    fraction: 1
  )
  context.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()
  var output = bitmap
  if !transparent {
    // App Store icons require an opaque PNG, including no alpha channel.
    guard let rgb = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: size,
      pixelsHigh: size,
      bitsPerSample: 8,
      samplesPerPixel: 3,
      hasAlpha: false,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: size * 3,
      bitsPerPixel: 24
    ), let source = bitmap.bitmapData, let destination = rgb.bitmapData else {
      fatalError("Unable to make opaque \(size)px icon")
    }
    for y in 0..<size {
      for x in 0..<size {
        let input = y * bitmap.bytesPerRow + x * 4
        let target = y * rgb.bytesPerRow + x * 3
        destination[target] = source[input]
        destination[target + 1] = source[input + 1]
        destination[target + 2] = source[input + 2]
      }
    }
    output = rgb
  }
  guard let data = output.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode \(size)px icon")
  }
  return data
}

func write(_ path: String, size: Int, width: CGFloat = 0.74, transparent: Bool = false) {
  let url = URL(fileURLWithPath: path)
  try! FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try! render(size: size, visibleWidthFraction: width, transparent: transparent)
    .write(to: url, options: .atomic)
  print("\(path): \(size)x\(size)")
}

write("assets/app_icon_1024.png", size: 1024)
write("assets/app_icon_256.png", size: 256)

let iosDirectory = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
let contents = try! Data(contentsOf: URL(fileURLWithPath: "\(iosDirectory)/Contents.json"))
let catalog = try! JSONSerialization.jsonObject(with: contents) as! [String: Any]
for entry in catalog["images"] as! [[String: Any]] {
  guard let filename = entry["filename"] as? String,
        let sizeText = entry["size"] as? String,
        let scaleText = entry["scale"] as? String,
        let points = Double(sizeText.split(separator: "x")[0]),
        let scale = Int(scaleText.dropLast()) else { continue }
  write("\(iosDirectory)/\(filename)", size: Int(points * Double(scale)))
}

for (folder, size) in [
  ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
  ("xxhdpi", 144), ("xxxhdpi", 192)
] {
  write("android/app/src/main/res/mipmap-\(folder)/ic_launcher.png", size: size)
  // Adaptive icon foregrounds use a full 108dp canvas at each density.
  write("android/app/src/main/res/mipmap-\(folder)/ic_launcher_foreground.png",
        size: size * 108 / 48, width: 0.60, transparent: true)
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
  write("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_\(size).png", size: size)
}

// Windows .ico files can contain PNG images at multiple native resolutions.
func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
  var littleEndian = value.littleEndian
  withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

let windowsSizes = [16, 32, 48, 64, 128, 256]
let windowsImages = windowsSizes.map { render(size: $0, visibleWidthFraction: 0.74) }
var icon = Data()
appendLittleEndian(UInt16(0), to: &icon)
appendLittleEndian(UInt16(1), to: &icon)
appendLittleEndian(UInt16(windowsSizes.count), to: &icon)
var imageOffset = UInt32(6 + 16 * windowsSizes.count)
for (size, image) in zip(windowsSizes, windowsImages) {
  icon.append(UInt8(size == 256 ? 0 : size))
  icon.append(UInt8(size == 256 ? 0 : size))
  icon.append(0) // palette colors; zero means full color
  icon.append(0) // reserved
  appendLittleEndian(UInt16(1), to: &icon)
  appendLittleEndian(UInt16(32), to: &icon)
  appendLittleEndian(UInt32(image.count), to: &icon)
  appendLittleEndian(imageOffset, to: &icon)
  imageOffset += UInt32(image.count)
}
for image in windowsImages { icon.append(image) }
try! icon.write(to: URL(fileURLWithPath: "windows/runner/resources/app_icon.ico"), options: .atomic)
print("windows/runner/resources/app_icon.ico: \(windowsSizes)")

write("web/favicon.png", size: 32)
write("web/icons/Icon-192.png", size: 192)
write("web/icons/Icon-512.png", size: 512)
write("web/icons/Icon-maskable-192.png", size: 192, width: 0.60)
write("web/icons/Icon-maskable-512.png", size: 512, width: 0.60)
